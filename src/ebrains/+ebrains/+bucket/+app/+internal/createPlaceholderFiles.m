function pathsWithoutPlaceholder = createPlaceholderFiles(rootFolder, paths)
% createPlaceholderFiles - Create empty placeholder files below a folder
%
%   pathsWithoutPlaceholder = ebrains.bucket.app.internal.createPlaceholderFiles(rootFolder, paths)
%   creates an empty file for each path, relative to rootFolder and with
%   "/" separators, and the folders of the paths. A file that exists is
%   kept: it may hold downloaded data.
%
%   A path gets no placeholder when something else is in its way: a
%   folder or a symbolic link at the path, or a file where a folder of the
%   path must go. Opening a dangling link for writing would create the
%   file it points to, outside rootFolder. Such paths are returned as a
%   string column, and the other paths get their placeholders. Before
%   R2024b links are found with Java, which needs an absolute rootFolder,
%   and without Java no link is found.
%
%   See also ebrains.bucket.app.internal.replaceWithPlaceholders, ebrains.bucket.createVirtualBucket

    arguments
        rootFolder (1,1) string
        paths string
    end

    pathsWithoutPlaceholder = strings(0, 1);
    for relativePath = reshape(paths, 1, [])
        filePath = fullfile(rootFolder, relativePath);
        if isfile(filePath)
            continue
        end
        if ~createEmptyFile(filePath)
            pathsWithoutPlaceholder(end+1, 1) = relativePath; %#ok<AGROW>
        end
    end
end

function wasCreated = createEmptyFile(filePath)
% createEmptyFile - Create an empty file and its folders, unless something is in the way
    wasCreated = false;
    % A dangling link is neither a file nor a folder
    if isfolder(filePath) || ebrains.bucket.sync.internal.isSymbolicLink(filePath)
        return
    end

    % mkdir gives false when a file has the name of the folder or of one
    % of the folders above it
    parentFolder = fileparts(filePath);
    if ~isfolder(parentFolder) && ~mkdir(parentFolder)
        return
    end

    fileID = fopen(filePath, "w");
    if fileID == -1
        return
    end
    fclose(fileID);
    wasCreated = true;
end
