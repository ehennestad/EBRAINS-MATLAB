function [actions, isCancelled] = runSync(direction, localFolder, bucketName, options)
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
%
%   The sync reports its progress to an
%   ebrains.bucket.internal.SyncProgressObserver: the one in
%   options.ProgressObserver, or a new
%   ebrains.bucket.internal.SyncProgressWindow when options.DisplayMode
%   is "Window". When the observer asks to cancel, the file in progress
%   stops, the files not yet copied or deleted are skipped, and a warning
%   says that the sync is incomplete. isCancelled is true then.

    arguments
        direction (1,1) string {mustBeMember(direction, ["ToBucket", "FromBucket"])}
        localFolder (1,1) string
        bucketName (1,1) string
        options (1,1) struct
    end

    prefix = ebrains.bucket.internal.normalizePrefix(options.Prefix);
    description = ebrains.bucket.internal.describeSync(direction, localFolder, bucketName, prefix);

    % The per-file display of the transfers is turned off while the
    % window shows their progress.
    if options.DisplayMode == "Window"
        options.ProgressObserver = ebrains.bucket.internal.SyncProgressWindow(description);
        options.DisplayMode = "None";
    end

    try
        [actions, isCancelled] = runSteps(direction, localFolder, bucketName, prefix, description, options);
    catch ME
        options.ProgressObserver.syncFailed(ME)
        rethrow(ME)
    end
end

function [actions, isCancelled] = runSteps(direction, localFolder, bucketName, prefix, description, options)
% runSteps - List, plan, copy and delete, reporting to options.ProgressObserver

    isToBucket = direction == "ToBucket";
    observer = options.ProgressObserver;

    % 1. List both sides
    observer.phaseStarted("listing")
    localFiles = ebrains.bucket.internal.listLocalFiles(localFolder);
    remoteFiles = ebrains.bucket.internal.listRemoteFiles(bucketName, prefix, options.Client);
    localFiles = ebrains.bucket.internal.excludeFiles(localFiles, options.Exclude);
    remoteFiles = ebrains.bucket.internal.excludeFiles(remoteFiles, options.Exclude);

    if options.Comparison == "Checksum"
        observer.phaseStarted("checksums")
        localFiles = addLocalChecksums(localFiles, remoteFiles, localFolder, observer);
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
        fprintf('%s\n', description);
        printPlanSummary(actions, isCopy, isDelete, copyAction)
    end

    if options.DryRun
        actions.Status(isCopy | isDelete) = "planned";
        if options.Verbose
            printPlannedActions(actions, isCopy | isDelete)
        end
        observer.planReady(actions)
        observer.syncFinished(actions)
        isCancelled = false;
        return
    end
    observer.planReady(actions)

    % 3. Copy
    if ~isToBucket && ~isfolder(localFolder)
        mkdir(localFolder)
    end
    copyIndices = find(isCopy);
    isCancelled = false;
    if ~isempty(copyIndices)
        observer.phaseStarted("copying")
    end
    k = 0;
    while k < numel(copyIndices) && ~isCancelled
        k = k + 1;
        i = copyIndices(k);
        if observer.isCancelRequested()
            isCancelled = true;
            continue
        end
        relativePath = actions.Path(i);
        if options.Verbose
            fprintf('[%d/%d] %s %s (%s)\n', k, numel(copyIndices), ...
                capitalize(copyAction), relativePath, ...
                ebrains.bucket.internal.formatBytes(actions.Bytes(i)));
        end
        observer.fileStarted(i)
        progressFcn = @(progress) observer.bytesTransferred(i, ...
            progress.TransferredBytes, progress.TotalBytes);
        cancelRequestedFcn = @() observer.isCancelRequested();
        try
            localFile = fullfile(localFolder, relativePath);
            objectName = prefix + relativePath;
            if isToBucket
                ebrains.bucket.uploadFile(bucketName, objectName, localFile, ...
                    DisplayMode=options.DisplayMode, Client=options.Client, ...
                    Uploader=options.Uploader, ProgressFcn=progressFcn, ...
                    CancelRequestedFcn=cancelRequestedFcn);
            else
                ebrains.bucket.downloadFile(bucketName, objectName, localFile, ...
                    DisplayMode=options.DisplayMode, Client=options.Client, ...
                    Downloader=options.Downloader, ProgressFcn=progressFcn, ...
                    CancelRequestedFcn=cancelRequestedFcn);
                verifyDownloadedSize(localFile, actions.Bytes(i))
            end
            actions.Status(i) = "done";
        catch ME
            isCancelled = isCancellation(ME);
            if isCancelled
                actions.Status(i) = "cancelled";
                actions.Message(i) = "Cancelled while it was copied.";
            else
                actions.Status(i) = "failed";
                actions.Message(i) = string(ME.message);
            end
            if options.Verbose
                fprintf('  %s: %s\n', capitalize(actions.Status(i)), actions.Message(i));
            end
        end
        observer.fileFinished(i, actions.Status(i), actions.Message(i))
    end
    if isCancelled
        isNotCopied = isCopy & actions.Status == "";
        actions.Status(isNotCopied) = "skipped";
        actions.Message(isNotCopied) = "Not copied, since the sync was cancelled.";
    end

    % 4. Delete. A failed copy may mean the source was listed wrongly or
    % the connection is lost, so nothing is deleted after one, the way
    % rsync and rclone hold back deletions after an error. A cancelled
    % sync deletes nothing either, since the target is not yet complete.
    hasFailedCopy = any(actions.Status == "failed");
    deleteIndices = find(isDelete);
    if (hasFailedCopy || isCancelled) && ~isempty(deleteIndices)
        actions.Status(deleteIndices) = "skipped";
        if isCancelled
            actions.Message(deleteIndices) = "Not deleted, since the sync was cancelled.";
        else
            actions.Message(deleteIndices) = "Not deleted, since a file failed to copy.";
        end
        deleteIndices = [];
    end
    if ~isempty(deleteIndices)
        observer.phaseStarted("deleting")
    end
    k = 0;
    while k < numel(deleteIndices) && ~isCancelled
        k = k + 1;
        i = deleteIndices(k);
        if observer.isCancelRequested()
            isCancelled = true;
            continue
        end
        relativePath = actions.Path(i);
        if options.Verbose
            fprintf('[%d/%d] Delete %s\n', k, numel(deleteIndices), relativePath);
        end
        observer.fileStarted(i)
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
        observer.fileFinished(i, actions.Status(i), actions.Message(i))
    end
    if isCancelled
        isNotDeleted = isDelete & actions.Status == "";
        actions.Status(isNotDeleted) = "skipped";
        actions.Message(isNotDeleted) = "Not deleted, since the sync was cancelled.";
    end

    if options.Verbose
        fprintf('Done: %d copied, %d deleted, %d failed.\n', ...
            sum(isCopy & actions.Status == "done"), ...
            sum(isDelete & actions.Status == "done"), ...
            sum(actions.Status == "failed"));
    end

    ebrains.bucket.internal.warnIfIncomplete(actions, isCancelled)
    observer.syncFinished(actions)
end

function localFiles = addLocalChecksums(localFiles, remoteFiles, localFolder, observer)
% addLocalChecksums - Compute the checksums the comparison needs
%
%   Only a local file whose remote counterpart has the same size and a
%   known checksum is read: for any other file the size or the time
%   decides, and reading every file of a large folder would take long.
%
%   A cancel request stops the reading. The files left without a
%   checksum are then judged by time, which does not matter, because a
%   cancelled sync copies nothing after the plan.

    [isInRemote, remoteIndex] = ismember(localFiles.Path, remoteFiles.Path);
    for i = reshape(find(isInRemote), 1, [])
        if observer.isCancelRequested()
            return
        end
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
        sum(isCopy), copyAction, ebrains.bucket.internal.formatBytes(sum(actions.Bytes(isCopy))), ...
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

function tf = isCancellation(exception)
% isCancellation - Return whether an error is the stop of a cancelled transfer
    tf = ismember(exception.identifier, ...
        ["webprogress:upload:Cancelled", "webprogress:download:Cancelled"]);
end
