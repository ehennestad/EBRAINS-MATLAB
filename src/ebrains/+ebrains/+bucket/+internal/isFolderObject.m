function tf = isFolderObject(objects)
% isFolderObject - Find the objects of a bucket listing that stand for folders
%
%   tf = ebrains.bucket.internal.isFolderObject(objects) returns a logical
%   column with one element per object of a listing, as
%   ebrains.bucket.listBucketObjects returns it, that is true for the
%   objects that mark a folder rather than hold a file. An object store
%   has no folders, so a folder shows up as a placeholder object in one of
%   three ways:
%       - its name ends with "/"
%       - its content type is a directory type ("application/directory")
%       - other objects are named below it. Buckets migrated from the old
%         object storage mark a folder with an empty object that has
%         neither a trailing "/" nor a directory content type.
%
%   See also ebrains.bucket.createVirtualBucket, ebrains.bucket.listBucketObjects

    tf = false(numel(objects), 1);
    if isempty(objects)
        return
    end

    objectNames = reshape(string({objects.name}), [], 1);
    parentPaths = unique(getParentPaths(objectNames));

    tf = endsWith(objectNames, "/") | ismember(objectNames, parentPaths);

    if isfield(objects, 'content_type')
        for i = 1:numel(objects)
            contentType = objects(i).content_type;
            if (ischar(contentType) || isstring(contentType)) ...
                    && startsWith(string(contentType), "application/directory")
                tf(i) = true;
            end
        end
    end
end

function parentPaths = getParentPaths(objectNames)
% getParentPaths - Every folder path implied by a list of object names
%
%   For "a/b/c.txt" the implied folders are "a" and "a/b".

    parentPaths = strings(1, 0);
    for objectName = reshape(objectNames, 1, [])
        separatorIndices = strfind(objectName, "/");
        % A trailing "/" names the object itself as a folder, not a parent
        separatorIndices(separatorIndices == strlength(objectName)) = [];
        for separatorIndex = separatorIndices
            parentPaths(end+1) = extractBefore(objectName, separatorIndex); %#ok<AGROW>
        end
    end
end
