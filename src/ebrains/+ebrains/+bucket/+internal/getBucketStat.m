function bucketStat = getBucketStat(bucketName)
% getBucketStat - Get the stat record of a bucket from the data proxy
%
%   Syntax:
%       bucketStat = ebrains.bucket.internal.getBucketStat(bucketName)
%           returns a struct with the fields name, objects_count, bytes and
%           last_modified, as reported by the bucket's stat endpoint.
%
%   The stat endpoint answers in a single request, so callers that only
%   need the object count or the total size should use this instead of
%   listing every object of the bucket.

    arguments
        bucketName (1,1) string
    end

    baseApiUrl = ebrains.common.constant.DataProxyApiBaseUrl();

    authClient = ebrains.iam.DeviceFlowTokenClient.instance();
    authHeaderField = authClient.getAuthHeaderField();

    apiUrl = baseApiUrl + "buckets/" + bucketName + "/stat";

    method = matlab.net.http.RequestMethod.GET;
    request = matlab.net.http.RequestMessage(method, authHeaderField, []);

    response = request.send(apiUrl);

    if response.StatusCode ~= matlab.net.http.StatusCode.OK
        error('EBRAINS:Bucket:BucketStatRequestFailed', ...
            'Unable to get stats for bucket "%s" with status code: %s', ...
            bucketName, char(response.StatusCode))
    end

    bucketStat = response.Body.Data;
end
