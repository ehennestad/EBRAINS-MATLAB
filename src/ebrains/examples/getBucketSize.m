% Specify a bucket name:
bucketName = "d-ca602c23-364a-4c9b-943b-87d1b09a5821";

% Get the combined byte-size of all objects in the bucket
bucketSizeBytes = ebrains.bucket.getBucketSize(bucketName);

% Print the size in a readable unit. An empty bucket has size 0, whose
% logarithm is -Inf, so clamp the value used for picking the unit.
sizeUnit = ["bytes", "kB", "MB", "GB", "TB", "PB"];
unitScale = floor(log10(max(bucketSizeBytes, 1))/3);
bucketSize = bucketSizeBytes / 10^(3*unitScale);
fprintf('Bucket size is %.2f %s\n', bucketSize, sizeUnit(unitScale+1))
