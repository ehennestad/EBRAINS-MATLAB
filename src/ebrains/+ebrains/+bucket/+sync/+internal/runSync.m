function actions = runSync(direction, localFolder, bucketName, syncOptions, client)
% runSync - Make a bucket match a local folder, or a local folder match a bucket
%
%   actions = ebrains.bucket.sync.internal.runSync(direction, localFolder,
%   bucketName, syncOptions, client) does the work of
%   ebrains.bucket.sync.toBucket (direction "ToBucket") and
%   ebrains.bucket.sync.fromBucket (direction "FromBucket"), whose help
%   describes the table it returns. syncOptions is an
%   ebrains.bucket.sync.SyncOptions and client the BucketsClient that sends the
%   requests. The sync works in four steps:
%       1. List the files on both sides, without the excluded ones.
%       2. Plan what to copy and delete (ebrains.bucket.sync.internal.planSync).
%       3. Copy the new and changed files.
%       4. Delete the extraneous files, if asked to and no copy failed.
%   When localFolder is a virtual bucket (see
%   ebrains.bucket.internal.metadata.readBucketInfo), the sync must be of
%   its bucket and prefix, a sync to the bucket leaves its placeholders
%   alone, a sync from the bucket deletes the placeholders of removed
%   objects, and its manifest is updated from the listing the sync made.
%   A copy that fails does not stop the sync: the other files are copied,
%   the failure is recorded in the table, and a warning names the files
%   that failed once the sync is done.

    arguments
        direction (1,1) string {mustBeMember(direction, ["ToBucket", "FromBucket"])}
        localFolder (1,1) string
        bucketName (1,1) string
        syncOptions (1,1) ebrains.bucket.sync.SyncOptions
        client (1,1) ebrains.bucket.api.BucketsClient
    end

    % The exclude files are read before the bucket is listed, so a file
    % that cannot be used stops the sync before any request for it.
    excludePatterns = reshape(syncOptions.Exclude, [], 1);
    for excludeFile = reshape(syncOptions.ExcludeFrom, 1, [])
        excludePatterns = [excludePatterns; ...
            ebrains.bucket.sync.internal.readExcludeFile(excludeFile)]; %#ok<AGROW>
    end

    isToBucket = direction == "ToBucket";
    prefix = ebrains.bucket.internal.normalizePrefix(syncOptions.Prefix);
    remoteLabel = "bucket """ + bucketName + """";
    if prefix ~= ""
        remoteLabel = remoteLabel + ", folder """ + prefix + """";
    end

    % A virtual bucket of another bucket or folder would end up holding the
    % objects of two. A dry run changes nothing, so it shows the plan with
    % the refusal instead of stopping.
    bucketInfo = ebrains.bucket.internal.metadata.readBucketInfo(localFolder);
    otherBucket = ebrains.bucket.internal.metadata.otherBucketRefusal(bucketInfo, bucketName, prefix);
    if otherBucket ~= "" && ~syncOptions.DryRun
        error('EBRAINS:Bucket:Sync:OtherBucket', '%s', otherBucket)
    end
    isVirtualBucket = ~isempty(bucketInfo) && otherBucket == "";

    % 1. List both sides
    [localFiles, unreadableFolders, linkedFolders] = ebrains.bucket.sync.internal.listLocalFiles(localFolder);
    listedTime = datetime("now", TimeZone="UTC");
    remoteFiles = ebrains.bucket.sync.internal.listRemoteFiles(bucketName, prefix, client);
    listedFiles = remoteFiles;

    % On a file system that ignores case, such as the default ones of
    % macOS and Windows, a local file and an object whose names differ
    % only in case are one file: a download writes into the local file
    % and keeps its name. Matching them exactly would plan that file for
    % deletion as well. An upload compares names exactly, since the bucket
    % tells them apart.
    ignoreCase = ~isToBucket && ebrains.bucket.sync.internal.isCaseInsensitive(localFolder, localFiles.Path);

    % The exclude patterns are matched the way names are: where names are
    % matched without regard to case, so are the patterns, or an object
    % whose name differs only in case from an excluded local file would
    % be downloaded over it.
    localFiles = ebrains.bucket.sync.internal.excludeFiles(localFiles, excludePatterns, ...
        IgnoreCase=ignoreCase);
    remoteFiles = ebrains.bucket.sync.internal.excludeFiles(remoteFiles, excludePatterns, ...
        IgnoreCase=ignoreCase);

    % The files of a local folder that could not be read are missing from
    % the listing, so the plan would take them for deleted or extraneous.
    % Nothing is deleted then, the way rsync holds back deletions after an
    % error while listing. A folder that is excluded does not count.
    unreadableFolders = excludePaths(unreadableFolders, excludePatterns, ignoreCase);
    deletionHoldBack = "";
    if ~isempty(unreadableFolders)
        warning('EBRAINS:Bucket:Sync:UnreadableFolder', ...
            ['%d folder(s) below "%s" could not be read, for example "%s". ' ...
             'Their files could not be listed, so nothing is deleted.'], ...
            numel(unreadableFolders), localFolder, unreadableFolders(1));
        deletionHoldBack = "Not deleted, since a local folder could not be read.";
    end

    % The files of a linked folder are stored elsewhere, so they are not
    % synced, and are missing from the listing in the same way.
    linkedFolders = excludePaths(linkedFolders, excludePatterns, ignoreCase);
    if ~isempty(linkedFolders)
        warning('EBRAINS:Bucket:Sync:LinkedFolder', ...
            ['%d folder(s) below "%s" are symbolic links, for example "%s". ' ...
             'Their files are not synced, so nothing is deleted. Exclude the ' ...
             'links to sync the rest with deletions.'], ...
            numel(linkedFolders), localFolder, linkedFolders(1));
        if deletionHoldBack == ""
            deletionHoldBack = "Not deleted, since a local folder is a symbolic link.";
        end
    end

    if ignoreCase
        [remoteFiles, droppedPaths] = ebrains.bucket.sync.internal.dropCaseCollisions(remoteFiles);
        if ~isempty(droppedPaths)
            warning('EBRAINS:Bucket:Sync:CaseCollision', ...
                ['%d object(s) of %s have a name that differs from another only in ' ...
                 'case, which the local folder cannot hold apart, for example "%s". ' ...
                 'They are left out of the sync.'], ...
                numel(droppedPaths), remoteLabel, droppedPaths(1));
        end
    end

    warnIfRemoteTimesUnknown(localFiles, remoteFiles, syncOptions.Comparison, remoteLabel, ignoreCase)

    if syncOptions.Comparison == "Checksum"
        localFiles = addLocalChecksums(localFiles, remoteFiles, localFolder, ignoreCase);
    end

    % 2. Plan
    if isToBucket
        [sourceFiles, targetFiles] = deal(localFiles, remoteFiles);
        copyAction = "upload";
    else
        [sourceFiles, targetFiles] = deal(remoteFiles, localFiles);
        copyAction = "download";
    end

    actions = ebrains.bucket.sync.internal.planSync(sourceFiles, targetFiles, ...
        Comparison=syncOptions.Comparison, Delete=syncOptions.Delete, IgnoreCase=ignoreCase);
    manifestFiles = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
    if isVirtualBucket
        manifestFiles = ebrains.bucket.internal.metadata.readManifest(localFolder);
    end
    if isToBucket && isVirtualBucket
        % The listing just made says which objects are not empty now, and
        % the manifest which were not empty when the placeholders were
        % made, so that a placeholder of an object removed since is not
        % uploaded as a new empty object.
        actions = ebrains.bucket.sync.internal.protectPlaceholders( ...
            actions, localFiles, listedFiles, manifestFiles);
    elseif isVirtualBucket
        % The folder stands for the bucket, so the placeholder of an object
        % removed since the manifest stands for nothing and holds no data
        actions = ebrains.bucket.sync.internal.deleteRemovedPlaceholders( ...
            actions, localFiles, listedFiles, manifestFiles, IgnoreCase=ignoreCase);
    end
    actions.Action(actions.Action == "copy") = copyAction;

    % The status of each file is kept in plain arrays while the sync runs,
    % since assigning a table one element at a time is slow for buckets
    % with many objects, and put in the table at the end.
    nActions = height(actions);
    status = repmat("", nActions, 1);
    message = repmat("", nActions, 1);

    isCopy = actions.Action == copyAction;
    isDelete = actions.Action == "delete";
    [refusalId, refusal] = deletionRefusal(actions, isDelete, height(sourceFiles), syncOptions.MaxDelete);
    if otherBucket ~= ""
        refusal = otherBucket;
    end

    if syncOptions.Verbose
        if isToBucket
            fprintf('Syncing "%s" to %s.\n', localFolder, remoteLabel);
        else
            fprintf('Syncing %s to "%s".\n', remoteLabel, localFolder);
        end
        printPlanSummary(actions, isCopy, isDelete, copyAction)
    end

    if syncOptions.DryRun
        % A dry run shows the plan, a refusal included, rather than stop
        status(isCopy) = "planned";
        if otherBucket ~= ""
            status(isCopy) = "skipped";
            message(isCopy) = otherBucket;
        end
        skipReason = refusal;
        if skipReason == ""
            skipReason = deletionHoldBack;
        end
        if skipReason == ""
            status(isDelete) = "planned";
        else
            status(isDelete) = "skipped";
            message(isDelete) = skipReason;
        end
        if syncOptions.Verbose
            printPlannedActions(actions, isCopy | isDelete)
            if refusal ~= ""
                fprintf('[DryRun] A real run would stop before changing anything: %s\n', refusal);
            end
        end
        actions.Status = status;
        actions.Message = message;
        return
    end

    if refusal ~= ""
        error(char(refusalId), '%s', refusal)
    end

    % 3. Copy
    if ~isToBucket && ~isfolder(localFolder)
        mkdir(localFolder)
    end
    copyIndices = find(isCopy);
    [~, sourceIndices] = ismember(actions.Path, sourceFiles.Path);
    for k = 1:numel(copyIndices)
        i = copyIndices(k);
        relativePath = actions.Path(i);
        if syncOptions.Verbose
            fprintf('[%d/%d] %s %s (%s)\n', k, numel(copyIndices), ...
                capitalize(copyAction), relativePath, ...
                ebrains.util.getDataSizeLabel(actions.Bytes(i)));
        end
        try
            localFile = fullfile(localFolder, relativePath);
            objectName = prefix + relativePath;
            if isToBucket
                ebrains.bucket.uploadFile(bucketName, objectName, localFile, ...
                    DisplayMode=syncOptions.DisplayMode, Client=client, ...
                    Uploader=syncOptions.Uploader);
            else
                message(i) = ebrains.bucket.sync.internal.downloadAndReplace( ...
                    bucketName, objectName, localFile, ...
                    ExpectedBytes=sourceFiles.Bytes(sourceIndices(i)), ...
                    ModifiedTime=sourceFiles.ModifiedTime(sourceIndices(i)), ...
                    DisplayMode=syncOptions.DisplayMode, Client=client, ...
                    Downloader=syncOptions.Downloader);
            end
            status(i) = "done";
        catch ME
            status(i) = "failed";
            message(i) = string(ME.message);
            if syncOptions.Verbose
                fprintf('  Failed: %s\n', ME.message);
            end
        end
    end

    % 4. Delete. A failed copy may mean the source was listed wrongly or
    % the connection is lost, so nothing is deleted after one, the way
    % rsync and rclone hold back deletions after an error.
    if deletionHoldBack == "" && any(status == "failed")
        deletionHoldBack = "Not deleted, since a file failed to copy.";
    end
    deleteIndices = find(isDelete);
    if deletionHoldBack ~= "" && ~isempty(deleteIndices)
        status(deleteIndices) = "skipped";
        message(deleteIndices) = deletionHoldBack;
        deleteIndices = [];
    end
    for k = 1:numel(deleteIndices)
        i = deleteIndices(k);
        relativePath = actions.Path(i);
        if syncOptions.Verbose
            fprintf('[%d/%d] Delete %s\n', k, numel(deleteIndices), relativePath);
        end
        try
            if isToBucket
                ebrains.bucket.deleteObject(bucketName, prefix + relativePath, ...
                    Client=client);
            else
                ebrains.bucket.sync.internal.deleteLocalFile(fullfile(localFolder, relativePath))
            end
            status(i) = "done";
        catch ME
            status(i) = "failed";
            message(i) = string(ME.message);
            if syncOptions.Verbose
                fprintf('  Failed: %s\n', ME.message);
            end
        end
    end

    actions.Status = status;
    actions.Message = message;

    if isVirtualBucket
        updateManifest(localFolder, bucketName, prefix, listedFiles, listedTime, ...
            localFiles, manifestFiles, actions, isToBucket)
    end

    if syncOptions.Verbose
        fprintf('Done: %d copied, %d deleted, %d failed.\n', ...
            sum(isCopy & status == "done"), ...
            sum(isDelete & status == "done"), ...
            sum(status == "failed"));
    end

    isFailed = status == "failed";
    if any(isFailed)
        failedPaths = actions.Path(isFailed);
        warning('EBRAINS:Bucket:Sync:Incomplete', ...
            ['The sync is incomplete: %d file(s) failed, for example "%s". ' ...
             'The Status and Message variables of the returned table say ' ...
             'which and why. Run the sync again to retry them.'], ...
            numel(failedPaths), failedPaths(1));
    end
end

function paths = excludePaths(paths, excludePatterns, ignoreCase)
% excludePaths - Paths that the exclude patterns leave in
    pathTable = ebrains.bucket.sync.internal.excludeFiles( ...
        ebrains.bucket.sync.internal.makeFileTable(paths, zeros(size(paths))), ...
        excludePatterns, IgnoreCase=ignoreCase);
    paths = pathTable.Path;
end

function updateManifest(localFolder, bucketName, prefix, listedFiles, listedTime, localFiles, oldManifestFiles, actions, isToBucket)
% updateManifest - Record the listing of a sync as the manifest of a virtual bucket
%
%   A sync to the bucket changed it after the listing, so the files it
%   uploaded and the objects it deleted are applied to the listing, and
%   the placeholders of removed objects keep their entries. A failed
%   transfer leaves the entry as the listing gave it.
    manifestFiles = listedFiles;
    if isToBucket
        isDone = actions.Status == "done";
        uploadedPaths = actions.Path(isDone & actions.Action == "upload");
        deletedPaths = actions.Path(isDone & actions.Action == "delete");
        manifestFiles = ebrains.bucket.sync.internal.manifestAfterPush(listedFiles, ...
            localFiles(ismember(localFiles.Path, uploadedPaths), :), deletedPaths, ...
            localFiles, oldManifestFiles);
    end
    ebrains.bucket.internal.metadata.writeManifest(localFolder, manifestFiles)
    ebrains.bucket.internal.metadata.writeBucketInfo(localFolder, bucketName, prefix, listedTime)
end

function warnIfRemoteTimesUnknown(localFiles, remoteFiles, comparison, remoteLabel, ignoreCase)
% warnIfRemoteTimesUnknown - Say so when the time comparison cannot work
%
%   Without modification times, the default comparison judges every file
%   of the same size on both sides unchanged, which should not pass in
%   silence. Only files on both sides are compared by time, so the warning
%   is for those.

    if comparison ~= "SizeAndTime"
        return
    end
    isCommon = ismember(matchKeys(remoteFiles.Path, ignoreCase), matchKeys(localFiles.Path, ignoreCase));
    if any(isCommon) && all(isnat(remoteFiles.ModifiedTime(isCommon)))
        warning('EBRAINS:Bucket:Sync:NoRemoteTimes', ...
            ['The listing of %s reports no modification times, so files of ' ...
             'the same size on both sides are judged unchanged. Use ' ...
             'Comparison="Checksum" to compare their content instead.'], remoteLabel);
    end
end

function localFiles = addLocalChecksums(localFiles, remoteFiles, localFolder, ignoreCase)
% addLocalChecksums - Compute the checksums the comparison needs
%
%   Only a local file whose remote counterpart has the same size and a
%   known checksum is read: for any other file the size or the time
%   decides, and reading every file of a large folder would take long. A
%   file that cannot be read (locked, without permission, or gone since
%   the listing) keeps an unknown checksum and is judged by size and time
%   like the others, with a warning, rather than stop the sync.

    [isInRemote, remoteIndex] = ismember(matchKeys(localFiles.Path, ignoreCase), ...
        matchKeys(remoteFiles.Path, ignoreCase));
    unreadablePaths = strings(0, 1);
    for i = reshape(find(isInRemote), 1, [])
        j = remoteIndex(i);
        if remoteFiles.Hash(j) ~= "" && remoteFiles.Bytes(j) == localFiles.Bytes(i)
            try
                localFiles.Hash(i) = ebrains.bucket.sync.internal.computeMD5( ...
                    fullfile(localFolder, localFiles.Path(i)));
            catch
                unreadablePaths(end+1, 1) = localFiles.Path(i); %#ok<AGROW>
            end
        end
    end

    if ~isempty(unreadablePaths)
        warning('EBRAINS:Bucket:Sync:ChecksumUnavailable', ...
            ['%d local file(s) could not be read for a checksum, for example ' ...
             '"%s". They are judged by size and time instead.'], ...
            numel(unreadablePaths), unreadablePaths(1));
    end
end

function keys = matchKeys(paths, ignoreCase)
% matchKeys - What the paths of the two sides are matched by
    keys = paths;
    if ignoreCase
        keys = lower(paths);
    end
end

function [identifier, reason] = deletionRefusal(actions, isDelete, nSourceFiles, maxDelete)
% deletionRefusal - Why the planned deletions look like a mistake, or ""
%
%   Checked before anything is changed. The identifier is the error
%   identifier a real run stops with.

    identifier = "";
    reason = "";

    nDelete = sum(isDelete);
    if nDelete == 0
        return
    end

    % An empty source with Delete would empty the target. That is more
    % often a mistyped folder or prefix than what is wanted, and the
    % target can be emptied with deleteObject or delete instead.
    if nSourceFiles == 0
        identifier = "EBRAINS:Bucket:Sync:EmptySource";
        reason = sprintf(['The source has no files, so the sync would delete ' ...
            'all %d file(s) of the target. Check the folder and the prefix.'], nDelete);
        return
    end

    if nDelete > maxDelete
        identifier = "EBRAINS:Bucket:Sync:TooManyDeletions";
        reason = sprintf(['The sync would delete %d file(s), more than ' ...
            'MaxDelete (%d), for example "%s".'], ...
            nDelete, maxDelete, actions.Path(find(isDelete, 1)));
    end
end

function printPlanSummary(actions, isCopy, isDelete, copyAction)
    isExtraneousKept = actions.Reason == "extraneous" & ~isDelete;
    fprintf('%d file(s) to %s (%s), %d to delete, %d unchanged.\n', ...
        sum(isCopy), copyAction, ebrains.util.getDataSizeLabel(sum(actions.Bytes(isCopy))), ...
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
