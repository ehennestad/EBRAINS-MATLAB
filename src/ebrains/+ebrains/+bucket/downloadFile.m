function downloadFile(filePath, relativeFilePath, bucketName, progressDisplay)
% downloadFile - Download a file from an EBRAINS bucket (swift object storage)
    
    if strncmp(char(relativeFilePath), filesep, 1)
        relativeFilePath = char(relativeFilePath);
        relativeFilePath = relativeFilePath(2:end);
    end

    BASE_API_URL = nansen.module.sharebrain.constant.DataProxyBaseUrl;
    endpointPath = sprintf("buckets/%s/%s", bucketName, relativeFilePath);

    apiURL = BASE_API_URL + endpointPath;

    disp('Starting download.')

    % downloadURL = getDownloadUrl(apiURL, options) ??

    % TODO: 

    try
        webFileSize = nansen.module.sharebrain.internal.fileio.getWebFileSize(apiURL);
        [filePath] = downloadFile(filePath, apiURL, ShowFilename=true);
    catch ME
        fileSize = nansen.module.sharebrain.internal.fileio.getLocalFileSize(filePath);
        if fileSize ~= webFileSize
            delete(filePath)
            filePath = strrep(filePath, ' ', '\ ');
            [status, msg] = system( sprintf('touch %s', filePath ));
        end
        rethrow(ME)
    end

    %task.concrete.downloadFile(filePath, apiURL, 'ProgressDisplay', progressDisplay)
end

function downloadURL = getDownloadUrl(apiURL, options)
    arguments
        apiURL (1,1) string
        options.useToken (1,1) logical = false
    end

    if options.useToken
        accessToken = getToken();
    
        header = matlab.net.http.HeaderField(...
            "accept", "application/json", ...
            "Authorization", "Bearer " + accessToken);
    else
        header=[];
    end

    method = matlab.net.http.RequestMethod.GET;
    req = matlab.net.http.RequestMessage(method, header, []);
    [resp, ~, ~] = req.send(apiURL);
    
    if resp.StatusCode ~= matlab.net.http.StatusCode.OK
        error(string(resp.StatusLine))
    else
        downloadURL = resp.Body.Data.url;
    end
end

function accessToken = getToken()
    authClient = ebrains.getTokenManager();    
    accessToken = authClient.AccessToken;
end