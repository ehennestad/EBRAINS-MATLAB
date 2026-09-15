function fileSizeBytes = getFileSize(bucketName, objectName, options)
% getFileSize - Get the byte size of an object (file) in an EBRAINS Data Proxy bucket
%
%   Syntax:
%       fileSizeBytes = ebrains.bucket.getFileSize(bucketName, objectName)
%       returns the size of the object in bytes.
%
%       fileSizeBytes = ebrains.bucket.getFileSize(..., Client=client)
%       sends the request through the given client instead of a default one.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Name of the object, relative to the bucket root; a
%                    leading "/" is ignored.
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the request.
%                Meant for tests and custom clients; a default client is
%                created otherwise.
%
%   See also ebrains.bucket.getBucketSize, ebrains.bucket.listBucketObjects

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    objectName = ebrains.bucket.internal.removeLeadingSlash(objectName);

    % The listing reports the size of every object it returns, so a listing
    % narrowed to the object's name answers without a request to the object
    % itself. The prefix also matches longer names ("a.txt" and "a.txt.bak"),
    % hence the exact-name filter.
    page = options.Client.listObjects(bucketName, prefix=objectName);
    objects = page.objects;

    % jsondecode turns an empty JSON array into [], which has no name field,
    % so an empty listing cannot go through the name comparison.
    if ~isempty(objects)
        isMatch = strcmp({objects.name}, objectName);
    else
        isMatch = false;
    end

    if ~any(isMatch)
        error('EBRAINS:Bucket:ObjectNotFound', ...
            'Object "%s" was not found in bucket "%s".', objectName, bucketName)
    end

    fileSizeBytes = objects(isMatch).bytes;
end
