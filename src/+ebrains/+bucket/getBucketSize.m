% Specify a bucket name:
function bucketSizeBytes = getBucketSize(bucketName)
    arguments
        bucketName (1,1) string
    end

    % Run command to create virtual dataset bucket locally
    bucketObjects = ebrains.bucket.listBucketObjects(bucketName);
    
    bucketSizeBytes = sum([bucketObjects.bytes]);
end
