function n = getObjectCount(bucketName, options)
% getObjectCount - Get count for number of objects in bucket.
%
%   Syntax:
%       n = ebrains.bucket.getObjectCount(bucketName)
%
%   Name-Value Arguments
%       Verbose : Print the count.
%       Client  : ebrains.bucket.api.BucketsClient that sends the request.
%                 Meant for tests and custom clients; a default client is
%                 created otherwise.

    arguments
        bucketName (1,1) string
        options.Verbose (1,1) logical = false
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    bucketStat = options.Client.getBucketStat(bucketName);
    n = bucketStat.objects_count;

    if options.Verbose
        fprintf('Bucket contains %d objects.\n', n)
    end
end
