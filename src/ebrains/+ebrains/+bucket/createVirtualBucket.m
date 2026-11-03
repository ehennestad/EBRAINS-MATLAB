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
%   read. The folder is also recorded in the list of virtual buckets of
%   the user (see ebrains.bucket.listVirtualBuckets). A folder that is a
%   virtual bucket already must be one of the same bucket and prefix.
%   Files that exist are kept, so running the function
%   again adds placeholders for new objects. It also deletes the empty
%   placeholders of objects removed since the last listing; one that
%   holds data by the time it is deleted is kept, with a warning.
%
%   An object gets no placeholder when something else is in its way: a
%   folder or a symbolic link at its path, or a file where one of its
%   folders must go (see ebrains.bucket.internal.createPlaceholderFiles).
%   Such objects are counted in a warning, and the manifest records them
%   all the same, so the next run tries again.
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

    % A placeholder whose object is gone since the last listing stands for
    % nothing and holds no data, so it is deleted. The file is read again
    % right before, and kept if it holds data by then.
    [oldManifestFiles, hasManifest] = ebrains.bucket.internal.metadata.readManifest(virtualBucketRootPath);
    if hasManifest
        localFiles = ebrains.bucket.sync.internal.listLocalFiles(virtualBucketRootPath);
        ignoreCase = ebrains.bucket.sync.internal.isCaseInsensitive(virtualBucketRootPath, localFiles.Path);
        removedFiles = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects( ...
            localFiles, listedFiles, oldManifestFiles, IgnoreCase=ignoreCase);
        keptPaths = strings(0, 1);
        for removedPath = reshape(removedFiles.Path, 1, [])
            if ~ebrains.bucket.sync.internal.deletePlaceholder(virtualBucketRootPath, removedPath)
                keptPaths(end+1, 1) = removedPath; %#ok<AGROW>
            end
        end
        if ~isempty(keptPaths)
            warning('EBRAINS:Bucket:Sync:PlaceholderKept', ...
                ['%d file(s) were empty placeholders of objects the bucket no longer has when the ' ...
                 'folder was listed, but hold data now, for example "%s". They were kept, since ' ...
                 'their data may exist nowhere else.'], numel(keptPaths), keptPaths(1));
        end
    end

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
    pathsWithoutPlaceholder = ebrains.bucket.internal.createPlaceholderFiles( ...
        virtualBucketRootPath, listedFiles.Path);
    if options.Verbose
        fprintf("Created %d/%d virtual files\n", nFiles - numel(pathsWithoutPlaceholder), nFiles)
    end
    if ~isempty(pathsWithoutPlaceholder)
        warning('EBRAINS:Bucket:PlaceholderNotCreated', ...
            ['%d object(s) got no placeholder, since a file, folder or symbolic link of the folder ' ...
             'is in the way, for example "%s".'], numel(pathsWithoutPlaceholder), pathsWithoutPlaceholder(1));
    end

    ebrains.bucket.internal.metadata.writeManifest(virtualBucketRootPath, listedFiles)
    ebrains.bucket.internal.metadata.writeBucketInfo(virtualBucketRootPath, bucketName, prefix, listedTime)
    ebrains.bucket.internal.registry.recordFolderOpened(virtualBucketRootPath, bucketName, prefix)
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
