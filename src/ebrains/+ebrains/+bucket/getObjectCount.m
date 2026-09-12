function n = getObjectCount(bucketName, options)
% getObjectCount - Get count for number of objects in bucket.

    arguments
        bucketName (1,1) string
        options.Verbose = false
    end

    bucketStat = ebrains.bucket.internal.getBucketStat(bucketName);
    n = bucketStat.objects_count;

    if options.Verbose
        fprintf('Bucket contains %d objects.\n', n)
    end
end
