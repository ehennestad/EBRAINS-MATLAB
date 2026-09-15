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
%
%   See also ebrains.bucket.downloadFile

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        options.TargetFolder (1,1) string {mustBeFolder} = pwd()
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    filePath = fullfile(options.TargetFolder, objectName);

    % downloadFile creates the folders that are part of the object name and
    % leaves a file already at filePath untouched if the transfer fails.
    ebrains.bucket.downloadFile(bucketName, objectName, filePath, Client=options.Client);

    if nargout == 0
        clear filePath
    end
end
