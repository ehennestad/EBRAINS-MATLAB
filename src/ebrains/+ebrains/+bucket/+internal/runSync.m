function actions = runSync(direction, localFolder, bucketName, syncOptions, client)
% runSync - Make a bucket match a local folder, or a local folder match a bucket
%
%   actions = ebrains.bucket.internal.runSync(direction, localFolder,
%   bucketName, syncOptions, client) does the work of
%   ebrains.bucket.syncToBucket (direction "ToBucket") and
%   ebrains.bucket.syncFromBucket (direction "FromBucket"), whose help
%   describes the table it returns. syncOptions is an
%   ebrains.bucket.SyncOptions and client the BucketsClient that sends the
%   requests. The sync works in four steps:
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
        syncOptions (1,1) ebrains.bucket.SyncOptions
        client (1,1) ebrains.bucket.api.BucketsClient
    end

    isToBucket = direction == "ToBucket";
    prefix = normalizePrefix(syncOptions.Prefix);
    remoteLabel = "bucket """ + bucketName + """";
    if prefix ~= ""
        remoteLabel = remoteLabel + ", folder """ + prefix + """";
    end

    % 1. List both sides
    localFiles = ebrains.bucket.internal.listLocalFiles(localFolder);
    remoteFiles = ebrains.bucket.internal.listRemoteFiles(bucketName, prefix, client);
    localFiles = ebrains.bucket.internal.excludeFiles(localFiles, syncOptions.Exclude);
    remoteFiles = ebrains.bucket.internal.excludeFiles(remoteFiles, syncOptions.Exclude);

    warnIfRemoteTimesUnknown(localFiles, remoteFiles, syncOptions.Comparison, remoteLabel)

    if syncOptions.Comparison == "Checksum"
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
        Comparison=syncOptions.Comparison, Delete=syncOptions.Delete);
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
        if refusal == ""
            status(isDelete) = "planned";
        else
            status(isDelete) = "skipped";
            message(isDelete) = refusal;
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
                downloadAndReplace(bucketName, objectName, localFile, actions.Bytes(i), ...
                    syncOptions, client)
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
    hasFailedCopy = any(status == "failed");
    deleteIndices = find(isDelete);
    if hasFailedCopy && ~isempty(deleteIndices)
        status(deleteIndices) = "skipped";
        message(deleteIndices) = "Not deleted, since a file failed to copy.";
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
                deleteLocalFile(fullfile(localFolder, relativePath))
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

function prefix = normalizePrefix(prefix)
% normalizePrefix - Folder name in the bucket, without a leading "/" and with a trailing one
    prefix = ebrains.bucket.internal.removeLeadingSlash(prefix);
    if prefix ~= "" && ~endsWith(prefix, "/")
        prefix = prefix + "/";
    end
end

function warnIfRemoteTimesUnknown(localFiles, remoteFiles, comparison, remoteLabel)
% warnIfRemoteTimesUnknown - Say so when the time comparison cannot work
%
%   Without modification times, the default comparison judges every file
%   of the same size on both sides unchanged, which should not pass in
%   silence. Only files on both sides are compared by time, so the warning
%   is for those.

    if comparison ~= "SizeAndTime"
        return
    end
    isCommon = ismember(remoteFiles.Path, localFiles.Path);
    if any(isCommon) && all(isnat(remoteFiles.ModifiedTime(isCommon)))
        warning('EBRAINS:Bucket:Sync:NoRemoteTimes', ...
            ['The listing of %s reports no modification times, so files of ' ...
             'the same size on both sides are judged unchanged. Use ' ...
             'Comparison="Checksum" to compare their content instead.'], remoteLabel);
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
            localFiles.Hash(i) = ebrains.bucket.internal.computeMD5( ...
                fullfile(localFolder, localFiles.Path(i)));
        end
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

function downloadAndReplace(bucketName, objectName, localFile, expectedBytes, syncOptions, client)
% downloadAndReplace - Download to a temporary file, check it, and put it in place
%
%   The file at localFile is replaced only once the download is complete
%   and has the size the listing reports, so a failed download leaves it
%   as it was. The temporary file sits next to it, so that the move is a
%   rename on the same file system.

    targetFolder = fileparts(localFile);
    if strlength(targetFolder) > 0 && ~isfolder(targetFolder)
        mkdir(targetFolder)
    end
    temporaryFile = string(tempname(char(targetFolder))) + ".sync-part";
    temporaryFileCleanup = onCleanup(@() deleteIfFile(temporaryFile)); % runs on return or error

    ebrains.bucket.downloadFile(bucketName, objectName, temporaryFile, ...
        DisplayMode=syncOptions.DisplayMode, Client=client, ...
        Downloader=syncOptions.Downloader);

    fileInfo = dir(temporaryFile);
    if isempty(fileInfo)
        error('EBRAINS:Bucket:Sync:DownloadMissing', ...
            'The download of "%s" produced no file.', objectName)
    end
    if fileInfo(1).bytes ~= expectedBytes
        error('EBRAINS:Bucket:Sync:SizeMismatch', ...
            'The downloaded file "%s" has %d bytes, where the object has %d.', ...
            objectName, fileInfo(1).bytes, expectedBytes)
    end

    movefile(temporaryFile, localFile, "f")
end

function deleteIfFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end

function deleteLocalFile(filePath)
% deleteLocalFile - Delete one file, and fail with an error when it stays
%
%   delete reports a file it cannot remove with a warning rather than an
%   error, and expands "*" and "?" in the name to other files, so a name
%   with either is refused and the file is checked afterwards. The warning
%   is left to show, since it says why the file stayed.

    [~, name, extension] = fileparts(filePath);
    if contains(name + extension, ["*", "?"])
        error('EBRAINS:Bucket:Sync:WildcardInName', ...
            ['The file "%s" was not deleted: its name holds a wildcard ' ...
             'character, which delete would expand to other files.'], filePath)
    end

    delete(filePath)

    if isfile(filePath)
        error('EBRAINS:Bucket:Sync:NotDeleted', ...
            'The file "%s" could not be deleted.', filePath)
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
