function downloadFile(filePath, relativeFilePath, bucketName, progressDisplay)
% downloadFile - Download a file from an EBRAINS bucket (swift object storage)
    
    if strncmp(char(relativeFilePath), filesep, 1)
        relativeFilePath = char(relativeFilePath);
        relativeFilePath = relativeFilePath(2:end);
    end

    BASE_API_URL = ebrains.common.constant.DataProxyApiBaseUrl();
    endpointPath = sprintf("buckets/%s/%s", bucketName, relativeFilePath);

    apiURL = BASE_API_URL + endpointPath;

    disp('Starting download.')

    % downloadURL = getDownloadUrl(apiURL, options) ??

    % TODO: 

    % Resolve the expected size before the transfer so the cleanup below can
    % tell a partial download from one that completed before the error.
    webFileSize = ebrains.bucket.getFileSize(relativeFilePath, bucketName);

    try
        [filePath] = downloadFile(filePath, apiURL, ShowFilename=true);
    catch ME
        % A failed transfer can leave a partial file behind. Replace it with
        % an empty placeholder so a virtual bucket keeps its file listing.
        if isfile(filePath) && getLocalFileSize(filePath) ~= webFileSize
            delete(filePath)
            createEmptyFile(filePath)
        end
        rethrow(ME)
    end

    %task.concrete.downloadFile(filePath, apiURL, 'ProgressDisplay', progressDisplay)
end

function fileSizeBytes = getLocalFileSize(filePath)
    fileInfo = dir(filePath);
    fileSizeBytes = fileInfo.bytes;
end

function createEmptyFile(filePath)
% createEmptyFile - Create an empty placeholder file
%
%   Uses fopen rather than a shell command so paths with spaces or shell
%   metacharacters need no quoting and the function also works on Windows.

    [fileID, errorMessage] = fopen(filePath, "w");
    if fileID == -1
        % Warn rather than error: the caller is about to rethrow the download
        % error, which is the one the user needs to see.
        warning('EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
            'Failed to recreate the placeholder file %s:\n%s', filePath, errorMessage)
        return
    end
    fclose(fileID);
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
