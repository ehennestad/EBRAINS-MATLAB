function checkSourceAndTarget(client, bucketName, objectName, targetName, overwrite)
% checkSourceAndTarget - Refuse a rename or copy whose source is missing or whose target is taken
%
%   ebrains.bucket.internal.checkSourceAndTarget(client, bucketName,
%   objectName, targetName, overwrite) throws EBRAINS:Bucket:ObjectNotFound
%   when the bucket holds no object named objectName, and
%   EBRAINS:Bucket:TargetExists when it holds one named targetName and
%   overwrite is false. A name that ends with "/" is a folder and counts
%   as present when any object is named below it.
%
%   The Data Proxy queues a rename or copy and reports one that fails
%   only by mail, so these checks are the only answer the caller gets at
%   once. They send listing requests, never the rename or copy.
%
%   See also ebrains.bucket.internal.hasObject

    arguments
        client (1,1) ebrains.bucket.api.BucketsClient
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        targetName (1,1) string {mustBeNonzeroLengthText}
        overwrite (1,1) logical
    end

    if ~ebrains.bucket.internal.hasObject(client, bucketName, objectName)
        error('EBRAINS:Bucket:ObjectNotFound', ...
            'Object "%s" was not found in bucket "%s".', objectName, bucketName)
    end

    if ~overwrite && ebrains.bucket.internal.hasObject(client, bucketName, targetName)
        error('EBRAINS:Bucket:TargetExists', ...
            ['An object named "%s" is already in bucket "%s". Pass Overwrite=true to replace it, ' ...
             'or give another target name.'], targetName, bucketName)
    end
end
