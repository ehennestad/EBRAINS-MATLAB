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
    if isempty(info)
        error('EBRAINS:Common:NamespaceNotFound', ...
            'Namespace "%s" was not found. Add the folder that holds "+%s" to the MATLAB path.', ...
            namespaceName, strrep(namespaceName, ".", "/+"))
    end

    % A namespace can be spread over several path folders. The first one in
    % path order is returned, the same precedence MATLAB itself applies.
    pathName = info(1).path;
end
