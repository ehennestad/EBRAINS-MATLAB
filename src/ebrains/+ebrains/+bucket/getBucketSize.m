function bucketSizeBytes = getBucketSize(bucketName)
% getBucketSize - Get the combined byte-size of all objects in a bucket
    arguments
        bucketName (1,1) string
    end

    bucketStat = ebrains.bucket.internal.getBucketStat(bucketName);
    bucketSizeBytes = bucketStat.bytes;
end
