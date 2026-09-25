% Specify a bucket name:
bucketName = "d-ca602c23-364a-4c9b-943b-87d1b09a5821";

% Get the combined byte-size of all objects in the bucket
bucketSizeBytes = ebrains.bucket.getBucketSize(bucketName);

% Print the size in a readable unit
fprintf('Bucket size is %s\n', ebrains.util.getDataSizeLabel(bucketSizeBytes))
