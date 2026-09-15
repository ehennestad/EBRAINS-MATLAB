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
%   Name-Value Arguments
%       Verbose : Print progress while the pages of the listing arrive.
%       Client  : ebrains.bucket.api.BucketsClient that sends the requests.
%                 Meant for tests and custom clients; a default client is
%                 created otherwise.

    arguments
        bucketName (1,1) string
        virtualBucketRootPath (1,1) string
        options.Verbose = false
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    S = ebrains.bucket.listBucketObjects(bucketName, "Verbose", options.Verbose, "Client", options.Client);

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end

    for i = 1:numel(S)
        objectName = string(S(i).name);
        filePath = fullfile(virtualBucketRootPath, objectName);

        % The listing returns the objects of the bucket rather than the
        % folders implied by their names, so an entry stands for a folder
        % only where the bucket says so. Whether the name has an extension
        % says nothing: "README" and "Snakefile" are files.
        if isFolderEntry(S(i))
            if ~isfolder(filePath); mkdir(filePath); end
            continue
        end

        % The folders of the object's own name are created as needed; the
        % root of the virtual bucket is already in place.
        parentFolderPath = fileparts(filePath);
        if strlength(parentFolderPath) > 0 && ~isfolder(parentFolderPath)
            mkdir(parentFolderPath)
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
