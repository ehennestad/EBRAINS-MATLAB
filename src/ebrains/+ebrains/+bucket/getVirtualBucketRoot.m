function rootFolder = getVirtualBucketRoot()
% getVirtualBucketRoot - The folder where new virtual buckets are made
%
%   rootFolder = ebrains.bucket.getVirtualBucketRoot() returns the
%   absolute path set with ebrains.bucket.setVirtualBucketRoot, or ""
%   when none is set.
%
%   See also ebrains.bucket.setVirtualBucketRoot, ebrains.bucket.listVirtualBuckets

    registry = ebrains.bucket.internal.registry.readRegistry();
    rootFolder = registry.Root;
end
