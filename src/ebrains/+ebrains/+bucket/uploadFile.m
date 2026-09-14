function uploadFile(bucketName, objectName, sourceFile, options)
% uploadFile - Upload a file to an EBRAINS Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.uploadFile(bucketName, objectName, sourceFile)
%       uploads the local file sourceFile to the bucket, where it becomes
%       the object objectName. An existing object of that name is replaced.
%
%       ebrains.bucket.uploadFile(..., Client=client) sends the requests
%       through the given client instead of a default one.
%
%   Input Arguments
%       bucketName : Name of the bucket to upload to
%       objectName : Name of the object in the bucket, including any folder
%                    within the bucket, e.g. "data/session1/raw.bin". The
%                    name is relative to the bucket root; a leading "/" is
%                    ignored.
%       sourceFile : Path of the local file to upload
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the requests.
%                Meant for tests and custom clients; a default client is
%                created otherwise.
%
%   See also ebrains.bucket.downloadFile, ebrains.bucket.getBucketObject

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        sourceFile (1,1) string {mustBeFile}
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    % Names are relative to the bucket root, so a leading "/" would be
    % sent as an empty first folder.
    objectName = removeLeadingSlash(objectName);

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

function name = removeLeadingSlash(name)
    if startsWith(name, "/")
        name = extractAfter(name, 1);
    end
end
