function bucketSizeBytes = getBucketSize(bucketName)
% getBucketSize - Get the combined byte-size of all objects in a bucket
    arguments
        bucketName (1,1) string
    end

    % Run command to list all objects of the bucket
    bucketObjects = ebrains.bucket.listBucketObjects(bucketName);

    bucketSizeBytes = sum([bucketObjects.bytes]);
end
