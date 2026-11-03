function tf = hasObject(client, bucketName, objectName)
% hasObject - Whether a bucket holds an object of a name, or any object below a folder name
%
%   tf = ebrains.bucket.internal.hasObject(client, bucketName, objectName)
%   lists the bucket with the name as prefix and returns true when an
%   object has exactly that name. The prefix also matches longer names
%   ("a.txt" and "a.txt.bak"), hence the exact-name comparison.
%
%   A name that ends with "/" stands for a folder, and the function
%   returns true when any object is named below it. The listing is
%   narrowed to one object then, since one is enough to answer.
%
%   See also ebrains.bucket.renameObject, ebrains.bucket.copyObject

    arguments
        client (1,1) ebrains.bucket.api.BucketsClient
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
    end

    isFolderName = endsWith(objectName, "/");
    if isFolderName
        page = client.listObjects(bucketName, prefix=objectName, limit=1);
    else
        page = client.listObjects(bucketName, prefix=objectName);
    end
    objects = page.objects;

    % jsondecode turns an empty JSON array into [], which has no name field,
    % so an empty listing cannot go through the name comparison.
    if isempty(objects)
        tf = false;
    elseif isFolderName
        tf = true;
    else
        tf = any(strcmp({objects.name}, objectName));
    end
end
