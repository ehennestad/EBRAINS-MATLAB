function files = makeFileTable(paths, bytes, modifiedTimes, hashes)
% makeFileTable - Table of files, as the sync functions compare them
%
%   files = ebrains.bucket.sync.internal.makeFileTable(paths, bytes,
%   modifiedTimes, hashes) returns a table with one row per file and the
%   variables
%       Path         : Path relative to the synced folder, with "/" separators
%       Bytes        : Size of the file
%       ModifiedTime : Time of the last change, as a datetime in UTC. NaT
%                      where it is not known.
%       Hash         : Lowercase MD5 checksum, or "" where it is not known
%
%   Every input is reshaped to a column, so empty inputs of any shape give
%   a table with no rows. modifiedTimes and hashes may be left out, which
%   leaves them unknown.
%
%   See also ebrains.bucket.sync.internal.listLocalFiles,
%   ebrains.bucket.sync.internal.listRemoteFiles, ebrains.bucket.sync.internal.planSync

    arguments
        paths string
        bytes double
        modifiedTimes datetime = NaT(numel(paths), 1)
        hashes string = strings(numel(paths), 1)
    end

    paths = reshape(paths, [], 1);
    bytes = reshape(bytes, [], 1);
    modifiedTimes = reshape(modifiedTimes, [], 1);
    hashes = reshape(hashes, [], 1);

    % Times without a time zone cannot be compared with times that have
    % one, so every time is put in UTC, unknown times included. Times that
    % have a zone are converted; times without one are taken to be in UTC.
    modifiedTimes.TimeZone = "UTC";

    hashes(ismissing(hashes)) = "";
    hashes = lower(hashes);

    files = table(paths, bytes, modifiedTimes, hashes, ...
        'VariableNames', ["Path", "Bytes", "ModifiedTime", "Hash"]);
end
