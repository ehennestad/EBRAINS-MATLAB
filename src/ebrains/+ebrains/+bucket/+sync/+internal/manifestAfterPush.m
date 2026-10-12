function manifestFiles = manifestAfterPush(listedFiles, uploadedFiles, deletedPaths)
% manifestAfterPush - Manifest of a virtual bucket after a sync to the bucket
%
%   manifestFiles = ebrains.bucket.sync.internal.manifestAfterPush(
%   listedFiles, uploadedFiles, deletedPaths) returns the file table of the
%   listing the sync made, with the entry of each uploaded file replaced
%   or added and the entry of each deleted object removed, sorted by path.
%   An uploaded file gets its local size and checksum and an unknown
%   time: the time of the new object is only known from a new listing.

    arguments
        listedFiles table
        uploadedFiles table
        deletedPaths string
    end

    uploadedFiles.ModifiedTime(:) = NaT;
    isKept = ~ismember(listedFiles.Path, [uploadedFiles.Path; reshape(deletedPaths, [], 1)]);
    manifestFiles = sortrows([listedFiles(isKept, :); uploadedFiles], "Path");
end
