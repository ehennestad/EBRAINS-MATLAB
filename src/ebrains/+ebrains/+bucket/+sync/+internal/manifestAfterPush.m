function manifestFiles = manifestAfterPush(listedFiles, uploadedFiles, deletedPaths, localFiles, oldManifestFiles)
% manifestAfterPush - Manifest of a virtual bucket after a sync to the bucket
%
%   manifestFiles = ebrains.bucket.sync.internal.manifestAfterPush(
%   listedFiles, uploadedFiles, deletedPaths, localFiles, oldManifestFiles)
%   returns the file table of the listing the sync made, with the entry of
%   each uploaded file replaced or added and the entry of each deleted
%   object removed, sorted by path. An uploaded file gets its local size
%   and checksum and an unknown time: the time of the new object is only
%   known from a new listing.
%
%   A placeholder whose object is gone keeps its entry from the manifest
%   before the sync, oldManifestFiles, so that the next sync to the bucket
%   still protects it rather than upload it as a new, empty object.
%   localFiles are the files of the local folder at the sync.
%
%   See also ebrains.bucket.sync.internal.placeholdersOfRemovedObjects

    arguments
        listedFiles table
        uploadedFiles table
        deletedPaths string
        localFiles table
        oldManifestFiles table
    end

    removedPlaceholders = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects( ...
        localFiles, listedFiles, oldManifestFiles);
    uploadedFiles.ModifiedTime(:) = NaT;
    isKept = ~ismember(listedFiles.Path, [uploadedFiles.Path; reshape(deletedPaths, [], 1)]);
    manifestFiles = sortrows([listedFiles(isKept, :); removedPlaceholders; uploadedFiles], "Path");
end
