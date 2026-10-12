function name = folderName()
% folderName - Name of the folder at the root of a virtual bucket that describes it
%
%   name = ebrains.bucket.internal.metadata.folderName() returns ".ebrains".
%   The folder holds bucket.json, which names the bucket and the prefix,
%   and manifest.csv, the objects of the last listing. Its layout is that
%   of the sync contract shared with the ebrains-bucket-sync package, in
%   spec/README.md#virtual-buckets of that package.

    name = ".ebrains";
end
