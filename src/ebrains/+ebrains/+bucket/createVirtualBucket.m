function createVirtualBucket(bucketName, virtualBucketRootPath, options)
% createVirtualBucket - Create a virtual bucket locally.
%
%   This function will create a dataset with dummy files (i.e empty files)
%   for all objects in a bucket.
%
%   Syntax:
%       ebrains.bucket.createVirtualBucket(bucketName, virtualBucketRootPath)
%           creates the virtual dataset for a bucket in the folder
%           specified by virtualBucketRootPath
%
%       ebrains.bucket.createVirtualBucket(..., Prefix=PREFIX) creates only
%           the objects whose name starts with PREFIX. Their paths below
%           virtualBucketRootPath keep the prefix.
%
%   Name-Value Arguments
%       Prefix  : Only create objects whose name starts with this text.
%                 Default is "", which creates every object.
%       Verbose : Print progress while the pages of the listing arrive.
%       Client  : ebrains.bucket.api.BucketsClient that sends the requests.
%                 Meant for tests and custom clients; a default client is
%                 created otherwise.

    arguments
        bucketName (1,1) string
        virtualBucketRootPath (1,1) string
        options.Prefix (1,1) string = ""
        options.Verbose = false
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    S = ebrains.bucket.listBucketObjects(bucketName, "Prefix", options.Prefix, ...
        "Verbose", options.Verbose, "Client", options.Client);

    % A name that another object lives below is a folder, whatever the
    % entry itself says. Buckets migrated from the old object storage mark
    % their folders with empty objects that have neither a trailing "/"
    % nor a directory content type.
    objectNames = strings(1, 0);
    if ~isempty(S)
        objectNames = string({S.name});
    end
    parentPaths = unique(getParentPaths(objectNames));

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end

    for i = 1:numel(S)
        objectName = string(S(i).name);
        filePath = fullfile(virtualBucketRootPath, objectName);

        % The listing returns the objects of the bucket rather than the
        % folders implied by their names, so an entry stands for a folder
        % only where the bucket says so. Whether the name has an extension
        % says nothing: "README" and "Snakefile" are files.
        if isFolderEntry(S(i)) || ismember(objectName, parentPaths)
            if ~isfolder(filePath); mkdir(filePath); end
            continue
        end

        % The folders of the object's own name are created as needed; the
        % root of the virtual bucket is already in place.
        parentFolderPath = fileparts(filePath);
        if strlength(parentFolderPath) > 0 && ~isfolder(parentFolderPath)
            mkdir(parentFolderPath)
        end

        % A file that exists is kept: it may hold data downloaded since the
        % bucket was first cloned, and opening it for writing would empty it.
        if isfile(filePath)
            continue
        end

        % Create the empty file from MATLAB rather than via a shell command,
        % so object names with spaces or shell metacharacters need no quoting
        % and the function also works on Windows.
        [fileID, errorMessage] = fopen(filePath, "w");
        if fileID == -1
            error(...
                'EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
                'Failed to create virtual file for %s with error:\n%s', filePath, errorMessage)
        end
        fclose(fileID);

        if mod(i, 100) == 0 || i == numel(S)
            if options.Verbose
                fprintf("Created %d/%d virtual files\n", i, numel(S))
            end
        end
    end
end

function parentPaths = getParentPaths(objectNames)
% getParentPaths - Every folder path implied by a list of object names
%
%   For "a/b/c.txt" the implied folders are "a" and "a/b".

    parentPaths = strings(1, 0);
    for objectName = objectNames
        separatorIndices = strfind(objectName, "/");
        % A trailing "/" names the object itself as a folder, not a parent
        separatorIndices(separatorIndices == strlength(objectName)) = [];
        for separatorIndex = separatorIndices
            parentPaths(end+1) = extractBefore(objectName, separatorIndex); %#ok<AGROW>
        end
    end
end

function tf = isFolderEntry(object)
% isFolderEntry - Whether a listing entry stands for a folder
%
%   A name that ends with "/" is how the Data Proxy names a folder, and
%   the object store marks the placeholder object of a folder with a
%   directory content type. Everything else is a file.

    tf = endsWith(string(object.name), "/");

    if ~tf && isfield(object, 'content_type')
        tf = startsWith(string(object.content_type), "application/directory");
    end
end
