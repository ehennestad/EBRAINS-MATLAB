function assertNotBelowLinkedFolder(rootFolder, relativePath, objectName)
% assertNotBelowLinkedFolder - Error when a folder between the root and a path is a symbolic link
%
%   ebrains.bucket.sync.internal.assertNotBelowLinkedFolder(rootFolder,
%   relativePath, objectName) raises the error
%   EBRAINS:Bucket:Sync:LocalFolderIsLink when one of the folders of
%   relativePath below rootFolder is a symbolic link. The content of such
%   a folder is stored outside rootFolder, so a download into it would
%   write wherever the link points, which may be a folder that is not
%   meant to be written to, and the listing of the folder
%   (ebrains.bucket.sync.internal.listLocalFiles) leaves the files of a
%   linked folder out for the same reason. A sync from the bucket and
%   the virtual bucket browser call this before each download, so that
%   an object named below such a folder fails its row rather than being
%   written through the link. The folders are checked from the root
%   down, so the error names the first linked one. A folder that does
%   not exist is no link. Without Java no link is found, as in the
%   listing. objectName names the object in the error message.
%
%   relativePath is relative to rootFolder, with "/" separators, as the
%   paths of a listing are.
%
%   See also ebrains.bucket.sync.internal.isSymbolicLink,
%   ebrains.bucket.sync.internal.downloadAndReplace

    arguments
        rootFolder (1,1) string
        relativePath (1,1) string
        objectName (1,1) string
    end

    % Java resolves a relative path against its own working directory,
    % so the root is made absolute, the way the listing reads it
    rootListing = dir(rootFolder);
    isRootEntry = strcmp({rootListing.name}, '.');
    if any(isRootEntry)
        rootFolder = string(rootListing(find(isRootEntry, 1)).folder);
    end

    segments = cellstr(split(relativePath, "/"));
    for depth = 1:numel(segments) - 1
        folder = string(fullfile(rootFolder, segments{1:depth}));
        if ebrains.bucket.sync.internal.isSymbolicLink(folder)
            error('EBRAINS:Bucket:Sync:LocalFolderIsLink', ...
                ['The object "%s" was not downloaded, since its local folder "%s" ' ...
                 'is a symbolic link.'], objectName, folder)
        end
    end
end
