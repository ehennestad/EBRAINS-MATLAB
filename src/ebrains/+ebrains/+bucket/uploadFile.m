function uploadFile(sourceFile, objectName, bucketName, options)
% uploadFile - Upload a file to an EBRAINS Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.uploadFile(sourceFile, objectName, bucketName)
%       uploads the local file sourceFile to the bucket, where it becomes
%       the object objectName. An existing object of that name is replaced.
%
%       ebrains.bucket.uploadFile(..., Client=client) sends the requests
%       through the given client instead of a default one.
%
%   Input Arguments
%       sourceFile : Path of the local file to upload
%       objectName : Name of the object in the bucket, including any folder
%                    within the bucket, e.g. "data/session1/raw.bin".
%                    A leading "/" is ignored.
%       bucketName : Name of the bucket to upload to
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the requests.
%                Meant for tests and custom clients; a default client is
%                created otherwise.

    arguments
        sourceFile (1,1) string {mustBeFile}
        objectName (1,1) string {mustBeNonzeroLengthText}
        bucketName (1,1) string {mustBeNonzeroLengthText}
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    % Object names are "/"-delimited on every platform. A leading "/" would
    % otherwise be sent as part of the name.
    if startsWith(objectName, "/")
        objectName = extractAfter(objectName, 1);
    end

    uploadUrl = options.Client.getUploadUrl(bucketName, objectName);

    % The uploader only raises on failure when called without outputs, and
    % that error carries no identifier. Raise a namespaced one instead.
    [wasSuccess, response] = ebrains.external.filedownload.uploadFile(...
        sourceFile, uploadUrl, ShowFilename=true);

    if ~wasSuccess
        error('EBRAINS:Bucket:UploadFailed', ...
            'Upload of "%s" to object "%s" of bucket "%s" failed: %s', ...
            sourceFile, objectName, bucketName, string(response.StatusLine))
    end
end
