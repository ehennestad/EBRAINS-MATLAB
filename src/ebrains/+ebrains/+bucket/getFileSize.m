function fileSizeBytes = getFileSize(relativeFilePath, bucketName)
% getFileSize - Get byte size of a file in an EBRAINS bucket (swift object storage)

    if strncmp(char(relativeFilePath), filesep, 1)
        relativeFilePath = char(relativeFilePath);
        relativeFilePath = relativeFilePath(2:end);
    end

    BASE_API_URL = ebrains.common.constant.DataProxyApiBaseUrl();
    endpointPath = sprintf("buckets/%s/%s", bucketName, relativeFilePath);

    webFileUrl = matlab.net.URI(BASE_API_URL + endpointPath);

    req = matlab.net.http.RequestMessage('HEAD');
    response = req.send(webFileUrl);

    if strcmp( response.StatusCode, 'NotFound' )
        error('FILEIO:WebFileNotFound', 'File "%s" was not found', webFileUrl)
    end

    contentLengthField = response.getFields("Content-Length");
    
    fileSizeBytes = str2double(contentLengthField.Value);
end
