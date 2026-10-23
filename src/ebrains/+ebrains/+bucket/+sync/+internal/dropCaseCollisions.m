function [remoteFiles, droppedPaths] = dropCaseCollisions(remoteFiles)
% dropCaseCollisions - Leave out objects a folder that ignores case cannot hold apart
%
%   [remoteFiles, droppedPaths] = ebrains.bucket.sync.internal.dropCaseCollisions(remoteFiles)
%   keeps, of the objects of a remote file table whose paths differ only in
%   case, the first in the listing and leaves the others out: all of them
%   would be downloaded into the same local file. droppedPaths are the
%   paths left out, for the caller to report.
%
%   See also ebrains.bucket.sync.internal.isCaseInsensitive

    arguments
        remoteFiles table
    end

    [~, firstIndices] = unique(lower(remoteFiles.Path), "stable");
    isKept = false(height(remoteFiles), 1);
    isKept(firstIndices) = true;
    droppedPaths = remoteFiles.Path(~isKept);
    remoteFiles = remoteFiles(isKept, :);
end
