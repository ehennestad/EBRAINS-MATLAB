function copyObject(bucketName, objectName, targetName, options)
% copyObject - Copy an object (file) of a Data Proxy bucket to another name
%
%   Syntax:
%       ebrains.bucket.copyObject(bucketName, objectName, targetName)
%       writes a copy of the object under the name targetName, in the same
%       bucket, and leaves the object itself in place. The Data Proxy
%       copies the object within the object store, so no data passes
%       through MATLAB. Both names are relative to the root of the bucket;
%       a leading "/" is ignored. To copy a folder with everything in it,
%       end both names with "/".
%
%       The Data Proxy queues the copy and completes it in the background,
%       and reports a copy that fails only by mail. So before the request,
%       the function checks that the object is in the bucket (error
%       EBRAINS:Bucket:ObjectNotFound otherwise) and, unless Overwrite is
%       true, that no object has the target name (error
%       EBRAINS:Bucket:TargetExists otherwise). A folder is present when
%       any object is named below it. Neither check sends the copy, so a
%       refused copy produces no mail. The copy appears in the listing
%       once it has completed.
%
%       ebrains.bucket.copyObject(..., Name=Value) sets the options below.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Name of the object to copy
%       targetName : Name of the copy
%
%   Name-Value Arguments
%       Overwrite        : Replace an object that has the target name
%                          rather than refuse the copy. Default is false.
%       SendSuccessEmail : Let the Data Proxy mail the account once the
%                          copy is done. Default is false; a copy that
%                          fails is reported by mail either way.
%       Client           : ebrains.bucket.api.BucketsClient that sends the
%                          requests. Meant for tests and custom clients; a
%                          default client is created otherwise.
%
%   See also ebrains.bucket.renameObject, ebrains.bucket.deleteObject

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

    options.Client.copyObject(bucketName, objectName, targetName, ...
        SendSuccessEmail=options.SendSuccessEmail);
end
