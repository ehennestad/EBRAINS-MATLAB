function setVirtualBucketRoot(rootFolder)
% setVirtualBucketRoot - Set the folder where new virtual buckets are made
%
%   ebrains.bucket.setVirtualBucketRoot(rootFolder) records the absolute
%   path of the existing folder in the registry of virtual buckets of the
%   user. The virtual bucket browser proposes a folder below it for a new
%   virtual bucket, so that one needs only the name of its bucket, and
%   lists the virtual buckets directly below it whether or not they were
%   opened before. The setting is shared with the ebrains-bucket-sync
%   package.
%
%   ebrains.bucket.setVirtualBucketRoot("") removes the root folder.
%
%   Example:
%       ebrains.bucket.setVirtualBucketRoot("~/EBRAINS buckets")
%
%   See also ebrains.bucket.getVirtualBucketRoot, ebrains.bucket.listVirtualBuckets,
%   ebrains.bucket.app.VirtualBucketBrowser

    arguments
        rootFolder (1,1) string
    end

    if rootFolder ~= ""
        rootFolder = ebrains.bucket.internal.absoluteFolderPath(rootFolder);
    end
    ebrains.bucket.internal.registry.updateRegistry(@(registry) withRoot(registry, rootFolder));
end

function registry = withRoot(registry, rootFolder)
    registry.Root = rootFolder;
end
