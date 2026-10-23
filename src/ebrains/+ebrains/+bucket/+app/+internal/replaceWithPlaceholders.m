function replaceWithPlaceholders(rootFolder, paths)
% replaceWithPlaceholders - Empty downloaded files so that they are online only
%
%   ebrains.bucket.app.internal.replaceWithPlaceholders(rootFolder, paths)
%   replaces each file, given by its path relative to rootFolder with "/"
%   separators, with an empty placeholder file of the same name. The data
%   of the files is discarded. A path that is not a file is an error,
%   reported before any file is changed.
%
%   See also ebrains.bucket.app.internal.createPlaceholderFiles

    arguments
        rootFolder (1,1) string
        paths string
    end

    filePaths = fullfile(rootFolder, reshape(paths, 1, []));
    if isempty(filePaths)
        return
    end

    isMissing = ~arrayfun(@isfile, filePaths);
    if any(isMissing)
        error('EBRAINS:Bucket:FileNotFound', ...
            'The file "%s" does not exist, so no file was made online only.', ...
            filePaths(find(isMissing, 1)))
    end

    for filePath = filePaths
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
