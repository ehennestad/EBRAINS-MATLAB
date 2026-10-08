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

    isToBucket = direction == "ToBucket";
    prefix = normalizePrefix(syncOptions.Prefix);
    remoteLabel = "bucket """ + bucketName + """";
    if prefix ~= ""
        remoteLabel = remoteLabel + ", folder """ + prefix + """";
    end

    % 1. List both sides
    [localFiles, unreadableFolders] = ebrains.bucket.sync.internal.listLocalFiles(localFolder);
    remoteFiles = ebrains.bucket.sync.internal.listRemoteFiles(bucketName, prefix, client);
    localFiles = ebrains.bucket.sync.internal.excludeFiles(localFiles, syncOptions.Exclude);
    remoteFiles = ebrains.bucket.sync.internal.excludeFiles(remoteFiles, syncOptions.Exclude);

    % The files of a local folder that could not be read are missing from
    % the listing, so the plan would take them for deleted or extraneous.
    % Nothing is deleted then, the way rsync holds back deletions after an
    % error while listing. A folder that is excluded does not count.
    unreadableFolderTable = ebrains.bucket.sync.internal.excludeFiles( ...
        ebrains.bucket.sync.internal.makeFileTable(unreadableFolders, zeros(size(unreadableFolders))), ...
        syncOptions.Exclude);
    unreadableFolders = unreadableFolderTable.Path;
    deletionHoldBack = "";
    if ~isempty(unreadableFolders)
        warning('EBRAINS:Bucket:Sync:UnreadableFolder', ...
            ['%d folder(s) below "%s" could not be read, for example "%s". ' ...
             'Their files could not be listed, so nothing is deleted.'], ...
            numel(unreadableFolders), localFolder, unreadableFolders(1));
        deletionHoldBack = "Not deleted, since a local folder could not be read.";
    end

    % On a file system that ignores case, such as the default ones of
    % macOS and Windows, a local file and an object whose names differ
    % only in case are one file: a download writes into the local file
    % and keeps its name. Matching them exactly would plan that file for
    % deletion as well. An upload compares names exactly, since the bucket
    % tells them apart.
    ignoreCase = ~isToBucket && isCaseInsensitive(localFolder, localFiles.Path);
    if ignoreCase
        remoteFiles = dropCaseCollisions(remoteFiles, remoteLabel);
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
                message(i) = downloadAndReplace(bucketName, objectName, localFile, ...
                    sourceFiles(sourceIndices(i), :), syncOptions, client);
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
%   decides, and reading every file of a large folder would take long.

    [isInRemote, remoteIndex] = ismember(matchKeys(localFiles.Path, ignoreCase), ...
        matchKeys(remoteFiles.Path, ignoreCase));
    for i = reshape(find(isInRemote), 1, [])
        j = remoteIndex(i);
        if remoteFiles.Hash(j) ~= "" && remoteFiles.Bytes(j) == localFiles.Bytes(i)
            localFiles.Hash(i) = ebrains.bucket.sync.internal.computeMD5( ...
                fullfile(localFolder, localFiles.Path(i)));
        end
    end
end

function keys = matchKeys(paths, ignoreCase)
% matchKeys - What the paths of the two sides are matched by
    keys = paths;
    if ignoreCase
        keys = lower(paths);
    end
end

function tf = isCaseInsensitive(localFolder, localPaths)
% isCaseInsensitive - Whether the file system of a local folder ignores the case of names
%
%   A listed file whose path has letters is looked up with their case
%   changed. A file system that ignores case finds it under that path,
%   and the listing has no file of that path. Without such a file there is
%   nothing to look up, and the default file systems of macOS and Windows
%   are taken to ignore case and those of other platforms not to.

    hasLetters = upper(localPaths) ~= lower(localPaths);
    index = find(hasLetters, 1);
    if isempty(index)
        tf = ismac || ispc;
        return
    end

    probePath = upper(localPaths(index));
    if probePath == localPaths(index)
        probePath = lower(localPaths(index));
    end
    tf = ~ismember(probePath, localPaths) && isfile(fullfile(localFolder, probePath));
end

function remoteFiles = dropCaseCollisions(remoteFiles, remoteLabel)
% dropCaseCollisions - Leave out objects a folder that ignores case cannot hold apart
%
%   Of the objects whose paths differ only in case, the first in the
%   listing is kept and the others are left out with a warning: all of
%   them would be downloaded into the same local file.

    [~, firstIndices] = unique(lower(remoteFiles.Path), "stable");
    if numel(firstIndices) == height(remoteFiles)
        return
    end
    isKept = false(height(remoteFiles), 1);
    isKept(firstIndices) = true;
    droppedPaths = remoteFiles.Path(~isKept);
    warning('EBRAINS:Bucket:Sync:CaseCollision', ...
        ['%d object(s) of %s have a name that differs from another only in ' ...
         'case, which the local folder cannot hold apart, for example "%s". ' ...
         'They are left out of the sync.'], ...
        numel(droppedPaths), remoteLabel, droppedPaths(1));
    remoteFiles = remoteFiles(isKept, :);
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

function note = downloadAndReplace(bucketName, objectName, localFile, sourceFile, syncOptions, client)
% downloadAndReplace - Download to a temporary file, check it, and put it in place
%
%   The file at localFile is replaced only once the download is complete
%   and has the size the listing reports (sourceFile is the row of the
%   object in the remote file table), so a failed download leaves it as
%   it was. The temporary file sits next to it, so that the move is a
%   rename on the same file system. The file is then given the time of
%   its object; note is "" or says why that failed.

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
    if fileInfo(1).bytes ~= sourceFile.Bytes
        error('EBRAINS:Bucket:Sync:SizeMismatch', ...
            'The downloaded file "%s" has %d bytes, where the object has %d.', ...
            objectName, fileInfo(1).bytes, sourceFile.Bytes)
    end

    movefile(temporaryFile, localFile, "f")

    note = setModifiedTime(localFile, sourceFile.ModifiedTime);
end

function note = setModifiedTime(filePath, modifiedTime)
% setModifiedTime - Give a downloaded file the modification time of its object
%
%   A file with the time of its object is unchanged to the time
%   comparison of a later sync in either direction. With the time of its
%   download it would be newer than its object, and
%   ebrains.bucket.sync.toBucket would upload it again. MATLAB has no
%   function that sets the time of a file, so Java does it. Without Java,
%   or without a known time, the file keeps the time of its download.
%   note is "" or says why the time could not be set.

    note = "";
    if isnat(modifiedTime) || ~usejava('jvm')
        return
    end

    % Java resolves a relative path against its own working directory,
    % which need not be MATLAB's, so the path is made absolute.
    fileInfo = dir(filePath);
    absolutePath = fullfile(fileInfo(1).folder, fileInfo(1).name);
    epochMilliseconds = round(posixtime(modifiedTime) * 1000);
    if ~java.io.File(char(absolutePath)).setLastModified(epochMilliseconds)
        note = "Downloaded, but the file kept the time of the download, " + ...
            "so a sync to the bucket would upload it again.";
    end
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
