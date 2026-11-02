function checkSourceAndTarget(client, bucketName, objectName, targetName, overwrite)
% checkSourceAndTarget - Refuse a rename or copy that the proxy would accept and then fail or misapply
%
%   ebrains.bucket.internal.checkSourceAndTarget(client, bucketName,
%   objectName, targetName, overwrite) throws
%       EBRAINS:Bucket:SameName            when the two names are equal
%       EBRAINS:Bucket:FolderNameMismatch  when one name ends with "/"
%                                          (a folder) and the other does not
%       EBRAINS:Bucket:TargetWithinSource  when the target lies within the
%                                          source folder, so the folder
%                                          would go into itself
%       EBRAINS:Bucket:ObjectNotFound      when the bucket holds no object
%                                          named objectName
%       EBRAINS:Bucket:TargetExists        when it holds one named
%                                          targetName and overwrite is false
%   A folder counts as present when any object is named below it.
%
%   The Data Proxy queues a rename or copy and reports one that fails
%   only by mail, so these checks are the only answer the caller gets at
%   once. The name checks send nothing; the other two send listing
%   requests, never the rename or copy.
%
%   See also ebrains.bucket.internal.hasObject

    arguments
        client (1,1) ebrains.bucket.api.BucketsClient
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        targetName (1,1) string {mustBeNonzeroLengthText}
        overwrite (1,1) logical
    end

    if objectName == targetName
        error('EBRAINS:Bucket:SameName', ...
            'The target name "%s" is the name of the object itself. Give another target name.', targetName)
    end

    isFolder = endsWith(objectName, "/");
    if isFolder ~= endsWith(targetName, "/")
        error('EBRAINS:Bucket:FolderNameMismatch', ...
            ['The names "%s" and "%s" must both end with "/", for a folder, or neither, for an ' ...
             'object.'], objectName, targetName)
    end

    if isFolder && startsWith(targetName, objectName)
        error('EBRAINS:Bucket:TargetWithinSource', ...
            'The target "%s" lies within the folder "%s", which would go into itself.', ...
            targetName, objectName)
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
