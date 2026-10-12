function files = classifyFiles(localFiles, remoteFiles, options)
% classifyFiles - Give each file of a virtual bucket a state
%
%   files = ebrains.bucket.app.internal.classifyFiles(localFiles) judges
%   the files of a virtual bucket folder from the local files alone: an
%   empty file is a placeholder for an object that is online only, and any
%   other file holds downloaded data.
%
%   files = ebrains.bucket.app.internal.classifyFiles(localFiles, remoteFiles)
%   compares the local files with a listing of the bucket instead, as
%   ebrains.bucket.sync.fromBucket would: a downloaded file is unchanged if
%   its size is that of the object and the object was not uploaded after
%   the file was last changed.
%
%   Input Arguments
%       localFiles  : File table of the virtual bucket folder, as
%                     ebrains.bucket.sync.internal.listLocalFiles returns it
%       remoteFiles : File table of the bucket, with paths in the same form
%                     as those of localFiles. Leave out, or give [], when
%                     the bucket has not been listed.
%
%   Name-Value Arguments
%       IgnoreCase : Whether paths that differ only in case name the same
%                    file, as on a file system that ignores case. A local
%                    file matched this way takes the path of its object.
%                    Default is false.
%
%   Output Arguments
%       files : Table with one row per path found on either side, sorted by
%               path, and the variables
%               Path        - Path relative to the virtual bucket folder
%               LocalBytes  - Size of the local file, NaN if there is none
%               LocalTime   - Time of the last change of the local file
%               RemoteBytes - Size of the object, NaN if it is not known
%               State       - "online_only" : the local file is an empty
%                                             placeholder, or is missing
%                             "downloaded"  : the local file holds the data
%                             "differs"     : the local file differs from
%                                             the object
%                             "local_only"  : the bucket has no such object
%               The states are those of spec/README.md#file-states of the
%               ebrains-bucket-sync package.
%
%   See also ebrains.bucket.sync.internal.planSync, ebrains.bucket.app.VirtualBucketBrowser

    arguments
        localFiles table
        remoteFiles = []
        options.IgnoreCase (1,1) logical = false
    end

    if isempty(remoteFiles) && ~istable(remoteFiles)
        files = classifyLocalFiles(localFiles);
    else
        files = classifyAgainstListing(localFiles, remoteFiles, options.IgnoreCase);
    end
end

function files = classifyLocalFiles(localFiles)
% classifyLocalFiles - States from the sizes of the local files alone

    state = repmat("downloaded", height(localFiles), 1);
    state(localFiles.Bytes == 0) = "online_only";

    files = table(localFiles.Path, localFiles.Bytes, localFiles.ModifiedTime, ...
        NaN(height(localFiles), 1), state, ...
        'VariableNames', ["Path", "LocalBytes", "LocalTime", "RemoteBytes", "State"]);
    files = sortrows(files, "Path");
end

function files = classifyAgainstListing(localFiles, remoteFiles, ignoreCase)
% classifyAgainstListing - States from a comparison of the local files with the bucket

    % The plan of a download from the bucket says which local files differ
    % from their objects, by the rule ebrains.bucket.sync.fromBucket uses.
    plan = ebrains.bucket.sync.internal.planSync(remoteFiles, localFiles, IgnoreCase=ignoreCase);
    nFiles = height(plan);

    [isLocal, localIndex] = ismember(matchKeys(plan.Path, ignoreCase), matchKeys(localFiles.Path, ignoreCase));
    localBytes = NaN(nFiles, 1);
    localBytes(isLocal) = localFiles.Bytes(localIndex(isLocal));
    localTime = NaT(nFiles, 1, 'TimeZone', 'UTC');
    localTime(isLocal) = localFiles.ModifiedTime(localIndex(isLocal));

    [isRemote, remoteIndex] = ismember(plan.Path, remoteFiles.Path);
    remoteBytes = NaN(nFiles, 1);
    remoteBytes(isRemote) = remoteFiles.Bytes(remoteIndex(isRemote));

    state = repmat("downloaded", nFiles, 1);
    state(plan.Reason == "size" | plan.Reason == "newer" | plan.Reason == "checksum") = "differs";
    % An empty local file of an object that is not empty is the placeholder
    % of a virtual bucket, not a copy that differs.
    state(localBytes == 0 & remoteBytes > 0) = "online_only";
    state(plan.Reason == "new") = "online_only";
    state(plan.Reason == "extraneous") = "local_only";

    files = table(plan.Path, localBytes, localTime, remoteBytes, state, ...
        'VariableNames', ["Path", "LocalBytes", "LocalTime", "RemoteBytes", "State"]);
end

function keys = matchKeys(paths, ignoreCase)
% matchKeys - What the paths of the two sides are matched by
    keys = paths;
    if ignoreCase
        keys = lower(paths);
    end
end
