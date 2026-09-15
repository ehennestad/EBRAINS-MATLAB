function renameObject(bucketName, objectName, targetName, options)
% renameObject - Rename an object (file) in a Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.renameObject(bucketName, objectName, targetName)
%       gives the object the name targetName. Both names are relative to
%       the root of the bucket; a leading "/" is ignored.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Current name of the object
%       targetName : New name of the object
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the request.
%                Meant for tests and custom clients; a default client is
%                created otherwise.

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        targetName (1,1) string
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    % Names are relative to the bucket root, so a leading "/" would be
    % sent as an empty first folder.
    objectName = ebrains.bucket.internal.removeLeadingSlash(objectName);
    targetName = ebrains.bucket.internal.removeLeadingSlash(targetName);

    options.Client.renameObject(bucketName, objectName, targetName);
end
