function registry = removeFolder(registry, folderPath)
% removeFolder - Forget a folder; the folder itself is left as it is
%
%   registry = ebrains.bucket.internal.registry.removeFolder(registry,
%   folderPath) removes the entry of the folder, if it has one.
%
%   See also ebrains.bucket.internal.registry.recordOpen

    arguments
        registry (1,1) struct
        folderPath (1,1) string
    end

    registry.Folders(registry.Folders.Path == folderPath, :) = [];
end
