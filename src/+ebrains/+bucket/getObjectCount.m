function n = getObjectCount(bucketName, options)
% getObjectCount - Get count for number of objects in bucket.
    
    arguments
        bucketName (1,1) string
        options.Verbose = false
    end
        
    BASE_API_URL = "https://data-proxy.ebrains.eu/api/v1/buckets/";

    authClient = ebrains.iam.AuthenticationClient.instance();
    authHeaderField = authClient.getAuthHeaderField();

    apiURL = BASE_API_URL + bucketName + "/stat";

    method = matlab.net.http.RequestMethod.GET;
    req = matlab.net.http.RequestMessage(method, authHeaderField, []);

    response = req.send(apiURL);

    switch response.StatusCode
        case "OK"
            n = response.Body.Data.objects_count;
            if options.Verbose
                fprintf('Bucket contains %d objects.\n', n )
            end
        otherwise
            error('Unable to get object count for bucket "%s" with status code: %s', bucketName, response.StatusCode )
    end