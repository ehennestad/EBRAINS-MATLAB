% Specify a bucket name:
bucketName = "d-ca602c23-364a-4c9b-943b-87d1b09a5821";

% Creates the virtual dataset inside temp_data in the current working directory
virtualBucketRootPath = "temp_data";

% Run command to create virtual dataset bucket locally
sharebrain.createVirtualBucket(bucketName, virtualBucketRootPath, "Verbose", true)