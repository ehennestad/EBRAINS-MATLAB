% Specify a bucket name:
bucketName = "d-ca602c23-364a-4c9b-943b-87d1b09a5821";

% Run command to create virtual dataset bucket locally
bucketObjects = ebrains.bucket.listBucketObjects(bucketName);

bucketSizeBytes = sum([bucketObjects.bytes]);

sizeUnit = ["bytes", "kB", "MB", "GB"];

unitScale = floor( log10(bucketSizeBytes) / 3 );

bucketSize = bucketSizeBytes / 10^(3*unitScale);
fprintf('Bucket size is %.2f %s\n', bucketSize, sizeUnit(unitScale))
