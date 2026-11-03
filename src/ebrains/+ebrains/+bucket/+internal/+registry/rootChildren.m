function paths = rootChildren(rootFolder)
% rootChildren - Paths of the folders directly below the root, sorted by name
%
%   paths = ebrains.bucket.internal.registry.rootChildren(rootFolder)
%   returns a string column. A root of "" (none set), or one that cannot
%   be read, gives no folders.
%
%   See also ebrains.bucket.internal.registry.listVirtualBuckets

    arguments
        rootFolder (1,1) string
    end

    paths = strings(0, 1);
    if rootFolder == "" || ~isfolder(rootFolder)
        return
    end
    listing = dir(rootFolder);
    listing = listing([listing.isdir] & ~ismember({listing.name}, {'.', '..'}));
    names = sort(reshape(string({listing.name}), [], 1));
    paths = fullfile(rootFolder, names);
end
