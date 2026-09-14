function filePath = getBucketObject(bucketName, objectName, options)
% getBucketObject - Download an object (file) from a Data Proxy bucket
%
%   Syntax:
%       filePath = ebrains.bucket.getBucketObject(bucketName, objectName)
%       downloads an object from the given bucket into the current folder
%       and returns the path of the downloaded file.
%
%       filePath = ebrains.bucket.getBucketObject(..., TargetFolder=folder)
%       downloads into the given folder instead. Folders that are part of
%       the object name are created below it.
%
%   Input Arguments
%       bucketName : Name of the bucket to get the object from
%       objectName : Name of the object (file) to download
%
%   Name-Value Arguments
%       TargetFolder : Folder to download into. Default is the current folder.
%       Client       : ebrains.bucket.api.BucketsClient that sends the
%                      requests. Meant for tests and custom clients; a
%                      default client is created otherwise.

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        options.TargetFolder (1,1) string {mustBeFolder} = pwd()
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    downloadUrl = options.Client.getDownloadUrl(bucketName, objectName);

    filePath = fullfile(options.TargetFolder, objectName);

    % Object names can contain "/" (folders within the bucket), so the
    % folder that will hold the file may not exist yet.
    targetFileFolder = fileparts(filePath);
    if ~isfolder(targetFileFolder)
        mkdir(targetFileFolder)
    end

    ebrains.internal.extern.fex.filedownload.downloadFile(filePath, downloadUrl);

    if nargout == 0
        clear filePath
    end
end
