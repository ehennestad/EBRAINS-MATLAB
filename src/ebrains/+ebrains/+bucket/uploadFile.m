function uploadFile(sourceFile, targetPath, bucketName)
% uploadFile - Upload file to an EBRAINS Data-Proxy bucket

    arguments
        sourceFile (1,1) string {mustBeFile}
        targetPath (1,1) string
        bucketName (1,1) string
    end

    if startsWith(targetPath, filesep)
        targetPath = extractAfter(targetPath, 1);
    end

    BASE_API_URL = ebrains.common.constant.DataProxyApiBaseUrl();
    endpointPath = sprintf("buckets/%s/data/%s", bucketName, targetPath);

    apiURL = BASE_API_URL + endpointPath;

    uploadURL = getUploadUrl(apiURL);

    [wasSuccess, response] = ebrains.external.filedownload.uploadFile(sourceFile, uploadURL, ShowFilename=true);
end

function uploadURL = getUploadUrl(apiURL)

    accessToken = getToken();

    header = matlab.net.http.HeaderField(...
        "accept", "application/json", ...
        "Authorization", "Bearer " + accessToken);

    warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
    warningReset = onCleanup(@() warning(warnState));

    method = matlab.net.http.RequestMethod.PUT;
    req = matlab.net.http.RequestMessage(method, header, []);
    [resp, ~, ~] = req.send(apiURL);
    
    if resp.StatusCode ~= matlab.net.http.StatusCode.OK
        error(string(resp.StatusLine))
    else
        uploadURL = resp.Body.Data.url;
    end
end

function accessToken = getToken()
    authClient = ebrains.getTokenManager();    
    accessToken = authClient.AccessToken;
end
