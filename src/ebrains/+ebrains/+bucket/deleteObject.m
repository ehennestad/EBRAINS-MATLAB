function deleteObject(bucketName, objectName, options)
% deleteObject - Delete an object (file) from a Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.deleteObject(bucketName, objectName) removes the
%       object from the bucket. The name is relative to the bucket root; a
%       leading "/" is ignored. To delete a folder with everything in it,
%       end objectName with "/". The Data Proxy processes a folder
%       deletion asynchronously and confirms it by email, so the objects
%       may remain listed for a while after the call returns.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Name of the object to delete
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the request.
%                Meant for tests and custom clients; a default client is
%                created otherwise.
%
%   See also ebrains.bucket.renameObject, ebrains.bucket.uploadFile

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    objectName = ebrains.bucket.internal.removeLeadingSlash(objectName);

    options.Client.deleteObject(bucketName, objectName);
end
