function wasDeleted = deletePlaceholder(rootFolder, relativePath)
% deletePlaceholder - Delete the placeholder of a removed object, if it is still an empty file
%
%   wasDeleted = ebrains.bucket.sync.internal.deletePlaceholder(rootFolder,
%   relativePath) deletes the file at relativePath below rootFolder when
%   it holds 0 bytes, and returns true. A file that holds data is left as
%   it is, and wasDeleted is false: the file was an empty placeholder
%   when the folder was listed, but something wrote into it since, and
%   now that its object is gone from the bucket its data may exist
%   nowhere else. A file that is gone already needs no deletion, and
%   wasDeleted is true.
%
%   The file is read right before it is deleted, with
%   ebrains.bucket.sync.internal.listLocalFile, so that the decision
%   rests on the file as it is now rather than on the listing that found
%   the placeholder: a sync lists the folder before its downloads, which
%   can take long, and the virtual bucket browser keeps the listing of
%   its last scan. A file that still exists after delete is an error, as
%   in ebrains.bucket.sync.internal.deleteLocalFile.
%
%   See also ebrains.bucket.sync.internal.placeholdersOfRemovedObjects,
%   ebrains.bucket.sync.internal.deleteLocalFile

    arguments
        rootFolder (1,1) string
        relativePath (1,1) string
    end

    file = ebrains.bucket.sync.internal.listLocalFile(rootFolder, relativePath);
    if isempty(file)
        wasDeleted = true;
        return
    end
    if file.Bytes > 0
        wasDeleted = false;
        return
    end
    ebrains.bucket.sync.internal.deleteLocalFile(fullfile(rootFolder, relativePath))
    wasDeleted = true;
end
