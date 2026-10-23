function createPlaceholderFiles(rootFolder, paths)
% createPlaceholderFiles - Create empty placeholder files below a folder
%
%   ebrains.bucket.app.internal.createPlaceholderFiles(rootFolder, paths)
%   creates an empty file for each path, relative to rootFolder and with
%   "/" separators, and the folders of the paths. A file that exists is
%   kept: it may hold downloaded data.
%
%   See also ebrains.bucket.app.internal.replaceWithPlaceholders, ebrains.bucket.createVirtualBucket

    arguments
        rootFolder (1,1) string
        paths string
    end

    for relativePath = reshape(paths, 1, [])
        filePath = fullfile(rootFolder, relativePath);
        if isfile(filePath)
            continue
        end

        parentFolder = fileparts(filePath);
        if ~isfolder(parentFolder)
            mkdir(parentFolder)
        end
        writeEmptyFile(filePath)
    end
end

function writeEmptyFile(filePath)
% writeEmptyFile - Create a file, or empty it if it exists
    [fileID, errorMessage] = fopen(filePath, "w");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
            'Failed to create the placeholder file "%s": %s', filePath, errorMessage)
    end
    fclose(fileID);
end
