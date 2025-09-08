function completeObjectList = listBucketObjects(bucketName, options)
% listBucketObjects - Get info for all objects of a bucket
%
%   Syntax:
%       S = ebrains.bucket.listBucketObjects(bucketName) returns a struct
%           array where each element contains info about a bucket object 
%           (i.e a file)
%
%   Input Arguments
%       bucketName : Name of the bucket to get object information from

    arguments
        bucketName (1,1) string
        options.Verbose = false
    end
        
    BASE_API_URL = ebrains.common.constant.DataProxyApiBaseUrl();

    authClient = ebrains.iam.AuthenticationClient.instance();
    authHeaderField = authClient.getAuthHeaderField();

    apiURL = BASE_API_URL + "buckets/" + bucketName;

    method = matlab.net.http.RequestMethod.GET;
    req = matlab.net.http.RequestMessage(method, authHeaderField, []);

    % Get bucket stats:
    nTotalObjects = ebrains.bucket.getObjectCount(bucketName);

    pageSize = 10000;
    marker = "";

    finished = false;
    completeObjectList = struct.empty;
        
    tBegin = tic; 
    while ~finished

        QP = matlab.net.QueryParameter('limit', pageSize, 'marker', marker);
        apiURI = matlab.net.URI(apiURL, QP);
        
        if options.Verbose
            fprintf('Sending request for bucket objects... ')
        end

        response = req.send(apiURI);

        switch response.StatusCode
            case "OK"
                objectList = response.Body.Data.objects;
            otherwise
                error('Unable to get file manifest for dataset "%s" with status code: %s', bucketName, resp.StatusCode )
        end

        if isempty(completeObjectList)
            completeObjectList = objectList;
        else
            completeObjectList = cat(1, completeObjectList, objectList); %#ok<AGROW>
        end
            
        if options.Verbose
            fprintf('Retrieved %d/%d objects.\n', numel(completeObjectList), nTotalObjects)
        end

        if isempty(objectList)
            return
        end
        
        marker = objectList(end).name;

        if numel(objectList) < pageSize
            finished = true;
        end
    end

    tElapsed = toc(tBegin);
    if options.Verbose
        fprintf('Retrieved %d objects in %.2f seconds.\n', ...
            numel(completeObjectList), tElapsed )
    end
end
