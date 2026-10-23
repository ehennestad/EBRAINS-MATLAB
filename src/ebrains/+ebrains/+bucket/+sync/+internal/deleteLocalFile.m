function deleteLocalFile(filePath)
% deleteLocalFile - Delete one file, and fail with an error when it stays
%
%   ebrains.bucket.sync.internal.deleteLocalFile(filePath) deletes the file.
%   delete reports a file it cannot remove with a warning rather than an
%   error, and expands "*" and "?" anywhere in the path to other files,
%   so a path with either is refused and the file is checked afterwards.
%   The warning is left to show, since it says why the file stayed.

    if contains(filePath, ["*", "?"])
        error('EBRAINS:Bucket:Sync:WildcardInName', ...
            ['The file "%s" was not deleted: its path holds a wildcard ' ...
             'character, which delete would expand to other files.'], filePath)
    end

    delete(filePath)

    if isfile(filePath)
        error('EBRAINS:Bucket:Sync:NotDeleted', ...
            'The file "%s" could not be deleted.', filePath)
    end
end
