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
        bucketName, prefix, options.Client, Verbose=logical(options.Verbose));

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end

    % The listing returns the objects of the bucket rather than the folders
    % implied by their names, so an entry stands for a folder only where the
    % bucket says so (see ebrains.bucket.internal.isFolderObject). Whether
    % the name has an extension says nothing: "README" and "Snakefile" are
    % files. The folders of the files are created with them; the folder
    % objects matter for folders that hold no file.
    for folderPath = reshape(folderPathsOf(S, prefix), 1, [])
        localFolder = fullfile(virtualBucketRootPath, folderPath);
        if ~isfolder(localFolder); mkdir(localFolder); end
    end

    % listedFiles holds the files below the prefix whose names are plain
    % relative paths below it (see ebrains.bucket.sync.internal.listRemoteFiles,
    % which warns about the others), the same files the manifest records.
    nFiles = height(listedFiles);
    for i = 1:nFiles
        filePath = fullfile(virtualBucketRootPath, listedFiles.Path(i));

        parentFolderPath = fileparts(filePath);
        if ~isfolder(parentFolderPath)
            mkdir(parentFolderPath)
        end

        % A file that exists is kept: it may hold data downloaded since the
        % bucket was first cloned, and opening it for writing would empty it.
        if ~isfile(filePath)
            createEmptyFile(filePath)
        end

        if options.Verbose && (mod(i, 100) == 0 || i == nFiles)
            fprintf("Created %d/%d virtual files\n", i, nFiles)
        end
    end

    ebrains.bucket.internal.metadata.writeManifest(virtualBucketRootPath, listedFiles)
    ebrains.bucket.internal.metadata.writeBucketInfo(virtualBucketRootPath, bucketName, prefix, listedTime)
end

function folderPaths = folderPathsOf(objects, prefix)
% folderPathsOf - Paths below the prefix of the objects that mark folders
%
%   The folder object of the prefix itself is the root, which is in place.
%   A folder named like the .ebrains folder would replace the description
%   of the virtual bucket, and a folder whose name below the prefix is not
%   a plain relative path is not created, as such files are not (see
%   ebrains.bucket.internal.isSafeRelativePath).
    folderPaths = strings(0, 1);
    if isempty(objects)
        return
    end
    names = reshape(string({objects.name}), [], 1);
    names = names(ebrains.bucket.internal.isFolderObject(objects));
    names = names(startsWith(names, prefix) & strlength(names) > strlength(prefix));
    folderPaths = regexprep(extractAfter(names, strlength(prefix)), "/$", "");
    folderPaths = folderPaths(ebrains.bucket.internal.isSafeRelativePath(folderPaths) ...
        & ~ebrains.bucket.internal.metadata.isMetadataPath(folderPaths));
end

function createEmptyFile(filePath)
% createEmptyFile - Create an empty file from MATLAB
%
%   A shell command would need the name quoted for spaces and
%   metacharacters, and would differ on Windows.
    [fileID, errorMessage] = fopen(filePath, "w");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
            'Failed to create virtual file for %s with error:\n%s', filePath, errorMessage)
    end
    fclose(fileID);
end
