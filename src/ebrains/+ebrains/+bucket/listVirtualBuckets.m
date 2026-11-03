function rows = listVirtualBuckets()
% listVirtualBuckets - List the virtual buckets of the user
%
%   rows = ebrains.bucket.listVirtualBuckets() returns a table with one
%   row per virtual bucket: the folders directly below the root folder
%   (see ebrains.bucket.setVirtualBucketRoot) whose .ebrains/bucket.json
%   can be read, merged with the folders recorded in the registry of the
%   user, which ebrains.bucket.app.VirtualBucketBrowser and
%   ebrains.bucket.createVirtualBucket add to when they open or make one.
%   The variables are
%       Path       : Absolute path of the folder
%       Bucket     : Name of its bucket
%       Prefix     : Folder of the bucket it holds, "" for the whole bucket
%       Label      : The label the user gave the bucket, "" for none
%       Pinned     : Whether the user pinned the folder to the top of the list
%       LastOpened : When the folder was last opened, in UTC, NaT for never
%       Exists     : Whether its bucket.json can be read now. A recorded
%                    folder that is missing, on a disk that is not
%                    mounted or no longer a virtual bucket stays listed
%                    with false, with the bucket and prefix it had.
%   Pinned folders come first, then the others from the last opened.
%
%   The registry is virtual-buckets.json in the configuration folder of
%   the user, shared with the ebrains-bucket-sync package (see
%   ebrains.bucket.internal.configFolder). The rules are those of
%   spec/README.md#virtual-bucket-registry of that package.
%
%   See also ebrains.bucket.app.VirtualBucketBrowser,
%   ebrains.bucket.setVirtualBucketRoot, ebrains.bucket.createVirtualBucket

    registry = ebrains.bucket.internal.registry.readRegistry();
    rows = ebrains.bucket.internal.registry.listVirtualBuckets(registry, ...
        ebrains.bucket.internal.registry.rootChildren(registry.Root), ...
        @ebrains.bucket.internal.registry.bucketInfoOf);
end
