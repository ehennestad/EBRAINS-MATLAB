function bucketSizeBytes = getBucketSize(bucketName, options)
% getBucketSize - Get the combined byte-size of all objects in a bucket
%
%   Syntax:
%       bucketSizeBytes = ebrains.bucket.getBucketSize(bucketName)
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the request.
%                Meant for tests and custom clients; a default client is
%                created otherwise.

    arguments
        bucketName (1,1) string
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    bucketStat = options.Client.getBucketStat(bucketName);
    bucketSizeBytes = bucketStat.bytes;
end
