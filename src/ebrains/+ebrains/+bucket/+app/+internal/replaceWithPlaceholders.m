function replaceWithPlaceholders(rootFolder, files)
% replaceWithPlaceholders - Empty downloaded files so that they are online only
%
%   ebrains.bucket.app.internal.replaceWithPlaceholders(rootFolder, files)
%   replaces each file of the file table files (see
%   ebrains.bucket.sync.internal.makeFileTable), given by its Path relative
%   to rootFolder with "/" separators, with an empty placeholder file of
%   the same name. The data of the files is discarded.
%
%   The rows of files are the files as they were read when the decision
%   to discard their data was made. A file is emptied only while it still
%   has the Bytes and ModifiedTime of its row: a file that is missing or
%   has changed since holds data that was not judged. Either is an error,
%   reported before any file is changed.
%
%   See also ebrains.bucket.app.internal.createPlaceholderFiles, ebrains.bucket.sync.internal.listLocalFile

    arguments
        rootFolder (1,1) string
        files table
    end

    for i = 1:height(files)
        filePath = fullfile(rootFolder, files.Path(i));
        current = ebrains.bucket.sync.internal.listLocalFile(rootFolder, files.Path(i));
        if isempty(current)
            error('EBRAINS:Bucket:FileNotFound', ...
                'The file "%s" does not exist, so no file was made online only.', filePath)
        end
        if current.Bytes ~= files.Bytes(i) || current.ModifiedTime ~= files.ModifiedTime(i)
            error('EBRAINS:Bucket:LocalFileChanged', ...
                ['The file "%s" changed since it was read, so no file was made online only. ' ...
                 'Refresh and try again.'], filePath)
        end
    end

    for filePath = reshape(fullfile(rootFolder, files.Path), 1, [])
        % Opening a file for writing empties it and keeps its name, which
        % is all a placeholder of a virtual bucket is.
        [fileID, errorMessage] = fopen(filePath, "w");
        if fileID == -1
            error('EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
                'Failed to empty the file "%s": %s', filePath, errorMessage)
        end
        fclose(fileID);
    end
end
