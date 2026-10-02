function actions = runSync(direction, localFolder, bucketName, options)
% runSync - Make a bucket match a local folder, or a local folder match a bucket
%
%   actions = ebrains.bucket.internal.runSync(direction, localFolder,
%   bucketName, options) does the work of ebrains.bucket.syncToBucket
%   (direction "ToBucket") and ebrains.bucket.syncFromBucket (direction
%   "FromBucket"), whose help describes the options and the table it
%   returns. It works in four steps:
%       1. List the files on both sides, without the excluded ones.
%       2. Plan what to copy and delete (ebrains.bucket.internal.planSync).
%       3. Copy the new and changed files.
%       4. Delete the extraneous files, if asked to and no copy failed.
%   A copy that fails does not stop the sync: the other files are copied,
%   the failure is recorded in the table, and a warning names the files
%   that failed once the sync is done.

    arguments
        direction (1,1) string {mustBeMember(direction, ["ToBucket", "FromBucket"])}
        localFolder (1,1) string
        bucketName (1,1) string
        options (1,1) struct
    end

    isToBucket = direction == "ToBucket";
    prefix = normalizePrefix(options.Prefix);
    remoteLabel = "bucket """ + bucketName + """";
    if prefix ~= ""
        remoteLabel = remoteLabel + ", folder """ + prefix + """";
    end

    % 1. List both sides
    localFiles = ebrains.bucket.internal.listLocalFiles(localFolder);
    remoteFiles = ebrains.bucket.internal.listRemoteFiles(bucketName, prefix, options.Client);
    localFiles = ebrains.bucket.internal.excludeFiles(localFiles, options.Exclude);
    remoteFiles = ebrains.bucket.internal.excludeFiles(remoteFiles, options.Exclude);

    if options.Comparison == "Checksum"
        localFiles = addLocalChecksums(localFiles, remoteFiles, localFolder);
    end

    % 2. Plan
    if isToBucket
        [sourceFiles, targetFiles] = deal(localFiles, remoteFiles);
        copyAction = "upload";
    else
        [sourceFiles, targetFiles] = deal(remoteFiles, localFiles);
        copyAction = "download";
    end

    actions = ebrains.bucket.internal.planSync(sourceFiles, targetFiles, ...
        Comparison=options.Comparison, Delete=options.Delete);
    actions.Action(actions.Action == "copy") = copyAction;
    actions.Status = repmat("", height(actions), 1);
    actions.Message = repmat("", height(actions), 1);

    isCopy = actions.Action == copyAction;
    isDelete = actions.Action == "delete";
    checkDeletions(actions, isDelete, height(sourceFiles), options.MaxDelete)

    if options.Verbose
        if isToBucket
            fprintf('Syncing "%s" to %s.\n', localFolder, remoteLabel);
        else
            fprintf('Syncing %s to "%s".\n', remoteLabel, localFolder);
        end
        printPlanSummary(actions, isCopy, isDelete, copyAction)
    end

    if options.DryRun
        actions.Status(isCopy | isDelete) = "planned";
        if options.Verbose
            printPlannedActions(actions, isCopy | isDelete)
        end
        return
    end

    % 3. Copy
    if ~isToBucket && ~isfolder(localFolder)
        mkdir(localFolder)
    end
    copyIndices = find(isCopy);
    for k = 1:numel(copyIndices)
        i = copyIndices(k);
        relativePath = actions.Path(i);
        if options.Verbose
            fprintf('[%d/%d] %s %s (%s)\n', k, numel(copyIndices), ...
                capitalize(copyAction), relativePath, formatBytes(actions.Bytes(i)));
        end
        try
            localFile = fullfile(localFolder, relativePath);
            objectName = prefix + relativePath;
            if isToBucket
                ebrains.bucket.uploadFile(bucketName, objectName, localFile, ...
                    DisplayMode=options.DisplayMode, Client=options.Client, ...
                    Uploader=options.Uploader);
            else
                ebrains.bucket.downloadFile(bucketName, objectName, localFile, ...
                    DisplayMode=options.DisplayMode, Client=options.Client, ...
                    Downloader=options.Downloader);
                verifyDownloadedSize(localFile, actions.Bytes(i))
            end
            actions.Status(i) = "done";
        catch ME
            actions.Status(i) = "failed";
            actions.Message(i) = string(ME.message);
            if options.Verbose
                fprintf('  Failed: %s\n', ME.message);
            end
        end
    end

    % 4. Delete. A failed copy may mean the source was listed wrongly or
    % the connection is lost, so nothing is deleted after one, the way
    % rsync and rclone hold back deletions after an error.
    hasFailedCopy = any(actions.Status == "failed");
    deleteIndices = find(isDelete);
    if hasFailedCopy && ~isempty(deleteIndices)
        actions.Status(deleteIndices) = "skipped";
        actions.Message(deleteIndices) = "Not deleted, since a file failed to copy.";
        deleteIndices = [];
    end
    for k = 1:numel(deleteIndices)
        i = deleteIndices(k);
        relativePath = actions.Path(i);
        if options.Verbose
            fprintf('[%d/%d] Delete %s\n', k, numel(deleteIndices), relativePath);
        end
        try
            if isToBucket
                ebrains.bucket.deleteObject(bucketName, prefix + relativePath, ...
                    Client=options.Client);
            else
                delete(fullfile(localFolder, relativePath))
            end
            actions.Status(i) = "done";
        catch ME
            actions.Status(i) = "failed";
            actions.Message(i) = string(ME.message);
            if options.Verbose
                fprintf('  Failed: %s\n', ME.message);
            end
        end
    end

    if options.Verbose
        fprintf('Done: %d copied, %d deleted, %d failed.\n', ...
            sum(isCopy & actions.Status == "done"), ...
            sum(isDelete & actions.Status == "done"), ...
            sum(actions.Status == "failed"));
    end

    isFailed = actions.Status == "failed";
    if any(isFailed)
        failedPaths = actions.Path(isFailed);
        warning('EBRAINS:Bucket:Sync:Incomplete', ...
            ['The sync is incomplete: %d file(s) failed, for example "%s". ' ...
             'The Status and Message variables of the returned table say ' ...
             'which and why. Run the sync again to retry them.'], ...
            numel(failedPaths), failedPaths(1));
    end
end

function prefix = normalizePrefix(prefix)
% normalizePrefix - Folder name in the bucket, without a leading "/" and with a trailing one
    prefix = regexprep(prefix, "^/+", "");
    if prefix ~= "" && ~endsWith(prefix, "/")
        prefix = prefix + "/";
    end
end

function localFiles = addLocalChecksums(localFiles, remoteFiles, localFolder)
% addLocalChecksums - Compute the checksums the comparison needs
%
%   Only a local file whose remote counterpart has the same size and a
%   known checksum is read: for any other file the size or the time
%   decides, and reading every file of a large folder would take long.

    [isInRemote, remoteIndex] = ismember(localFiles.Path, remoteFiles.Path);
    for i = reshape(find(isInRemote), 1, [])
        j = remoteIndex(i);
        if remoteFiles.Hash(j) ~= "" && remoteFiles.Bytes(j) == localFiles.Bytes(i)
            localFiles.Hash(i) = ebrains.bucket.internal.computeMd5( ...
                fullfile(localFolder, localFiles.Path(i)));
        end
    end
end

function checkDeletions(actions, isDelete, nSourceFiles, maxDelete)
% checkDeletions - Refuse deletions that look like a mistake, before anything is changed

    nDelete = sum(isDelete);
    if nDelete == 0
        return
    end

    % An empty source with Delete would empty the target. That is more
    % often a mistyped folder or prefix than what is wanted, and the
    % target can be emptied with deleteObject or delete instead.
    if nSourceFiles == 0
        error('EBRAINS:Bucket:Sync:EmptySource', ...
            ['The source has no files, so the sync would delete all %d ' ...
             'file(s) of the target. Check the folder and the prefix; ' ...
             'nothing was changed.'], nDelete)
    end

    if nDelete > maxDelete
        error('EBRAINS:Bucket:Sync:TooManyDeletions', ...
            ['The sync would delete %d file(s), more than MaxDelete (%d), ' ...
             'for example "%s". Nothing was changed. Run with DryRun=true ' ...
             'to see the plan.'], ...
            nDelete, maxDelete, actions.Path(find(isDelete, 1)))
    end
end

function verifyDownloadedSize(localFile, expectedBytes)
    fileInfo = dir(localFile);
    if isempty(fileInfo) || fileInfo(1).bytes ~= expectedBytes
        actualBytes = NaN;
        if ~isempty(fileInfo)
            actualBytes = fileInfo(1).bytes;
        end
        error('EBRAINS:Bucket:Sync:SizeMismatch', ...
            'The downloaded file "%s" has %d bytes, where the object has %d.', ...
            localFile, actualBytes, expectedBytes)
    end
end

function printPlanSummary(actions, isCopy, isDelete, copyAction)
    isExtraneousKept = actions.Reason == "extraneous" & ~isDelete;
    fprintf('%d file(s) to %s (%s), %d to delete, %d unchanged.\n', ...
        sum(isCopy), copyAction, formatBytes(sum(actions.Bytes(isCopy))), ...
        sum(isDelete), sum(actions.Reason == "unchanged"));
    if any(isExtraneousKept)
        fprintf(['%d file(s) of the target are not in the source and are ' ...
            'kept. Use Delete=true to delete them.\n'], sum(isExtraneousKept));
    end
end

function printPlannedActions(actions, isPlanned)
    for i = reshape(find(isPlanned), 1, [])
        fprintf('  [DryRun] %s %s (%s)\n', capitalize(actions.Action(i)), ...
            actions.Path(i), actions.Reason(i));
    end
end

function text = capitalize(text)
    text = upper(extractBefore(text, 2)) + extractAfter(text, 1);
end

function text = formatBytes(bytes)
    units = ["B", "KB", "MB", "GB", "TB"];
    exponent = min(floor(log(max(bytes, 1)) / log(1024)), numel(units) - 1);
    if exponent == 0
        text = sprintf('%d B', bytes);
    else
        text = sprintf('%.1f %s', bytes / 1024^exponent, units(exponent + 1));
    end
end
