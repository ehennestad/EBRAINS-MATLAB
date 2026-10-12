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
%       ebrains.bucket.createVirtualBucket(..., Prefix=FOLDER) creates only
%           the objects in a folder of the bucket. Paths below
%           virtualBucketRootPath are relative to that folder, as for
%           ebrains.bucket.sync.fromBucket: the object "results/a.txt" of
%           Prefix "results/" becomes the file "a.txt".
%
%   The folder .ebrains at the root records the bucket, the prefix and the
%   objects of the listing (see ebrains.bucket.internal.metadata.folderName),
%   which ebrains.bucket.app.VirtualBucketBrowser and the sync functions
%   read. A folder that is a virtual bucket already must be one of the same
%   bucket and prefix. Files that exist are kept, so running the function
%   again adds placeholders for new objects.
%
%   Name-Value Arguments
%       Prefix  : Folder of the bucket to create, such as "results/". A
%                 missing trailing "/" is added. Default is "", the whole
%                 bucket.
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

    prefix = ebrains.bucket.internal.normalizePrefix(options.Prefix);
    refusal = ebrains.bucket.internal.metadata.otherBucketRefusal( ...
        ebrains.bucket.internal.metadata.readBucketInfo(virtualBucketRootPath), bucketName, prefix);
    if refusal ~= ""
        error('EBRAINS:Bucket:OtherBucket', '%s', refusal)
    end

    listedTime = datetime("now", TimeZone="UTC");
    [listedFiles, S] = ebrains.bucket.sync.internal.listRemoteFiles( ...
        bucketName, prefix, options.Client, logical(options.Verbose));

    % The listing returns the objects of the bucket rather than the folders
    % implied by their names, so an entry stands for a folder only where the
    % bucket says so. Whether the name has an extension says nothing:
    % "README" and "Snakefile" are files.
    isFolder = ebrains.bucket.internal.isFolderObject(S);

    % Object names become paths below the root, so only plain relative
    % names are created. A name with a "." or ".." segment, an empty
    % segment (a leading or doubled "/") or a backslash is left out: it
    % could point outside the root, onto the path of another object, or to
    % a different path on Windows. Folder names end with "/", which the
    % check would read as an empty segment, hence the strip.
    objectNames = strings(1, 0);
    if ~isempty(S)
        objectNames = string({S.name});
    end
    isSafe = ebrains.bucket.internal.isSafeRelativePath(regexprep(objectNames, "/$", ""));
    if ~all(isSafe)
        warning('EBRAINS:Bucket:UnsafeObjectName', ...
            ['%d object(s) of bucket "%s" were not created because their names are not plain ' ...
             'relative paths (a ".", ".." or empty segment, or a backslash), for example "%s".'], ...
            sum(~isSafe), bucketName, objectNames(find(~isSafe, 1)));
    end

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end

    for i = 1:numel(S)
        if ~isSafe(i)
            continue
        end
        objectName = string(S(i).name);

        % The listing is narrowed to the prefix already. The folder object
        % of the prefix itself is the root, which is in place.
        if ~startsWith(objectName, prefix) || strlength(objectName) == strlength(prefix)
            continue
        end
        relativePath = extractAfter(objectName, strlength(prefix));
        % An object named like the .ebrains folder would replace the
        % description of the virtual bucket.
        if ebrains.bucket.internal.metadata.isMetadataPath(regexprep(relativePath, "/$", ""))
            continue
        end
        filePath = fullfile(virtualBucketRootPath, relativePath);

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

    ebrains.bucket.internal.metadata.writeManifest(virtualBucketRootPath, listedFiles)
    ebrains.bucket.internal.metadata.writeBucketInfo(virtualBucketRootPath, bucketName, prefix, listedTime)
end
