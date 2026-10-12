function files = classifyFiles(localFiles, remoteFiles)
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
%   Output Arguments
%       files : Table with one row per path found on either side, sorted by
%               path, and the variables
%               Path        - Path relative to the virtual bucket folder
%               LocalBytes  - Size of the local file, NaN if there is none
%               LocalTime   - Time of the last change of the local file
%               RemoteBytes - Size of the object, NaN if it is not known
%               State       - "OnlineOnly"  : the local file is an empty
%                                             placeholder, or is missing
%                             "Downloaded"  : the local file holds the data
%                             "Differs"     : the local file differs from
%                                             the object
%                             "LocalOnly"   : the bucket has no such object
%
%   See also ebrains.bucket.sync.internal.planSync, ebrains.bucket.app.VirtualBucketBrowser

    arguments
        localFiles table
        remoteFiles = []
    end

    if isempty(remoteFiles) && ~istable(remoteFiles)
        files = classifyLocalFiles(localFiles);
    else
        files = classifyAgainstListing(localFiles, remoteFiles);
    end
end

function files = classifyLocalFiles(localFiles)
% classifyLocalFiles - States from the sizes of the local files alone

    state = repmat("Downloaded", height(localFiles), 1);
    state(localFiles.Bytes == 0) = "OnlineOnly";

    files = table(localFiles.Path, localFiles.Bytes, localFiles.ModifiedTime, ...
        NaN(height(localFiles), 1), state, ...
        'VariableNames', ["Path", "LocalBytes", "LocalTime", "RemoteBytes", "State"]);
    files = sortrows(files, "Path");
end

function files = classifyAgainstListing(localFiles, remoteFiles)
% classifyAgainstListing - States from a comparison of the local files with the bucket

    % The plan of a download from the bucket says which local files differ
    % from their objects, by the rule ebrains.bucket.sync.fromBucket uses.
    plan = ebrains.bucket.sync.internal.planSync(remoteFiles, localFiles);
    nFiles = height(plan);

    [isLocal, localIndex] = ismember(plan.Path, localFiles.Path);
    localBytes = NaN(nFiles, 1);
    localBytes(isLocal) = localFiles.Bytes(localIndex(isLocal));
    localTime = NaT(nFiles, 1, 'TimeZone', 'UTC');
    localTime(isLocal) = localFiles.ModifiedTime(localIndex(isLocal));

    [isRemote, remoteIndex] = ismember(plan.Path, remoteFiles.Path);
    remoteBytes = NaN(nFiles, 1);
    remoteBytes(isRemote) = remoteFiles.Bytes(remoteIndex(isRemote));

    state = repmat("Downloaded", nFiles, 1);
    state(plan.Reason == "size" | plan.Reason == "newer" | plan.Reason == "checksum") = "Differs";
    % An empty local file of an object that is not empty is the placeholder
    % of a virtual bucket, not a copy that differs.
    state(localBytes == 0 & remoteBytes > 0) = "OnlineOnly";
    state(plan.Reason == "new") = "OnlineOnly";
    state(plan.Reason == "extraneous") = "LocalOnly";

    files = table(plan.Path, localBytes, localTime, remoteBytes, state, ...
        'VariableNames', ["Path", "LocalBytes", "LocalTime", "RemoteBytes", "State"]);
end
