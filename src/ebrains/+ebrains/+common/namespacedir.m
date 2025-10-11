function pathName = namespacedir(namespaceName)
% namespacedir - Retrieves the directory path name of the given namespace
%
% Syntax:
%   folderPathName = ebrains.common.namespacedir(namespace) Returns the
%   directory path name (location) of the given namespace.
%
% Output Arguments:
%   folderPathName - A string containing the full path to the namespace folder.

    arguments
        namespaceName (1,1) string
    end

    namespaceParts = strsplit(namespaceName, '.');
    namespaceParts = "+" + namespaceParts;
    namespaceRelativePath = fullfile(namespaceParts{:});

    info = what(namespaceRelativePath);
    pathName = info.path;
end
