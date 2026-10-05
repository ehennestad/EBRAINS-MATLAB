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

    % The listing returns the objects of the bucket rather than the folders
    % implied by their names, so an entry stands for a folder only where the
    % bucket says so. Whether the name has an extension says nothing:
    % "README" and "Snakefile" are files.
    isFolder = ebrains.bucket.internal.isFolderObject(S);

    % An object named with a ".." segment would be created outside the
    % root, so such names are left out. Folder names end with "/", which
    % the check would read as an empty segment, hence the strip.
    objectNames = strings(numel(S), 1);
    for i = 1:numel(S)
        objectNames(i) = string(S(i).name);
    end
    isSafe = ebrains.bucket.internal.isSafeRelativePath(regexprep(objectNames, "/$", ""));
    if ~all(isSafe)
        warning('EBRAINS:Bucket:UnsafeObjectName', ...
            ['%d object(s) of bucket "%s" have names that do not stay below ' ...
             'the root folder, for example "%s", and were not created.'], ...
            sum(~isSafe), bucketName, objectNames(find(~isSafe, 1)));
    end

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end

    for i = 1:numel(S)
        if ~isSafe(i)
            continue
        end
        objectName = objectNames(i);
        filePath = fullfile(virtualBucketRootPath, objectName);

        if isFolder(i)
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
