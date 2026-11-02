function renameObject(bucketName, objectName, targetName, options)
% renameObject - Rename an object (file) in a Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.renameObject(bucketName, objectName, targetName)
%       gives the object the name targetName. The Data Proxy moves the
%       object within the object store, so no data passes through MATLAB.
%       Both names are relative to the root of the bucket; a leading "/"
%       is ignored. To rename a folder with everything in it, end
%       objectName with "/".
%
%       The Data Proxy queues the rename and completes it in the
%       background, and reports a rename that fails only by mail. So
%       before the request, the function checks that the object is in the
%       bucket (error EBRAINS:Bucket:ObjectNotFound otherwise) and, unless
%       Overwrite is true, that no object has the target name (error
%       EBRAINS:Bucket:TargetExists otherwise). A folder is present when
%       any object is named below it. Two equal names, a folder name
%       paired with an object name, and a target within the source folder
%       are refused as well. No check sends the rename, so a refused
%       rename produces no mail. The object can be listed under both
%       names until the rename has completed.
%
%       ebrains.bucket.renameObject(..., Name=Value) sets the options below.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Current name of the object
%       targetName : New name of the object
%
%   Name-Value Arguments
%       Overwrite        : Replace an object that has the target name
%                          rather than refuse the rename. Default is false.
%       SendSuccessEmail : Let the Data Proxy mail the account once the
%                          rename is done. Default is false; a rename
%                          that fails is reported by mail either way.
%       Client           : ebrains.bucket.api.BucketsClient that sends the
%                          requests. Meant for tests and custom clients; a
%                          default client is created otherwise.
%
%   See also ebrains.bucket.copyObject, ebrains.bucket.deleteObject

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        targetName (1,1) string
        options.Overwrite (1,1) logical = false
        options.SendSuccessEmail (1,1) logical = false
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    % Names are relative to the bucket root, so a leading "/" would be
    % sent as an empty first folder.
    objectName = ebrains.bucket.internal.removeLeadingSlash(objectName);
    targetName = ebrains.bucket.internal.removeLeadingSlash(targetName);

    ebrains.bucket.internal.checkSourceAndTarget(options.Client, bucketName, objectName, targetName, ...
        options.Overwrite);

    options.Client.renameObject(bucketName, objectName, targetName, ...
        SendSuccessEmail=options.SendSuccessEmail);
end
