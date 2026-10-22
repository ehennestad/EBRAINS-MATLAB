function removedFiles = placeholdersOfRemovedObjects(localFiles, listedFiles, manifestFiles, options)
% placeholdersOfRemovedObjects - Find the placeholders of a virtual bucket whose object is gone
%
%   removedFiles = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects(
%   localFiles, listedFiles, manifestFiles) returns the manifest entries
%   of the local files that are placeholders of removed objects: files of
%   0 bytes that the new listing does not have, and whose manifest entry
%   has more than 0 bytes. Only the manifest says that such a file stands
%   for an object. The entries carry the paths of the local files and are
%   sorted by path. A virtual bucket that was never listed has an empty
%   manifest, and so has no such placeholders.
%
%   removedFiles = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects(...,
%   IgnoreCase=true) matches the paths of the three tables without regard
%   to case, for a folder whose file system ignores the case of names.
%
%   See also ebrains.bucket.sync.internal.protectPlaceholders,
%   ebrains.bucket.sync.internal.manifestAfterPush

    arguments
        localFiles table
        listedFiles table
        manifestFiles table
        options.IgnoreCase (1,1) logical = false
    end

    localKeys = matchKeys(localFiles.Path, options.IgnoreCase);
    isListed = ismember(localKeys, matchKeys(listedFiles.Path, options.IgnoreCase));
    [isInManifest, manifestIndex] = ismember(localKeys, matchKeys(manifestFiles.Path, options.IgnoreCase));

    manifestBytes = zeros(height(localFiles), 1);
    manifestBytes(isInManifest) = manifestFiles.Bytes(manifestIndex(isInManifest));
    isRemoved = localFiles.Bytes == 0 & ~isListed & manifestBytes > 0;

    removedFiles = manifestFiles(manifestIndex(isRemoved), :);
    removedFiles.Path = localFiles.Path(isRemoved);
    removedFiles = sortrows(removedFiles, "Path");
end

function keys = matchKeys(paths, ignoreCase)
% matchKeys - What the paths of the tables are matched by
    keys = paths;
    if ignoreCase
        keys = lower(paths);
    end
end
