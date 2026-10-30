classdef VirtualBucketBrowser < handle
% VirtualBucketBrowser - Browse a virtual bucket and choose which files to keep locally
%
%   A virtual bucket is a local folder that mirrors the names of the
%   objects of a Data Proxy bucket, with an empty placeholder file for each
%   object that is online only (see ebrains.bucket.createVirtualBucket).
%   The browser shows the folders and files of the virtual bucket, and
%   downloads the selected files or makes them online only again, which
%   replaces their local copies with empty placeholders.
%
%   Syntax:
%       ebrains.bucket.app.VirtualBucketBrowser(localFolder) opens the
%       virtual bucket in localFolder. Its folder .ebrains says which
%       bucket it stands for (see ebrains.bucket.internal.metadata.folderName).
%
%       ebrains.bucket.app.VirtualBucketBrowser() asks for the folder
%       first. Cancelling the dialog opens no browser.
%
%       ebrains.bucket.app.VirtualBucketBrowser(localFolder, BucketName=NAME)
%       also makes localFolder a virtual bucket of the bucket NAME if it is
%       not one yet. A folder that does not exist is created and filled
%       with placeholders from a listing of the bucket.
%
%       app = ebrains.bucket.app.VirtualBucketBrowser(...) also returns the
%       browser object.
%
%   Each file is compared with the manifest, the objects of the last
%   listing of the bucket, which the virtual bucket keeps. Listing a bucket
%   of many objects takes a while, so the bucket is listed again only when
%   "Update from bucket" is pressed. The update adds placeholders for
%   objects that the folder does not have yet, and deletes the
%   placeholders of objects removed from the bucket while they are still
%   empty; a file written into since the last scan is kept. The local
%   folder is read when the browser opens and when "Refresh" is pressed.
%   "Download" and "Make online only" read the selected files again
%   first, so that a file edited since is judged as it is now. A folder
%   that was never listed is judged from its files alone: an empty file
%   is online only and any other file is downloaded. "Open online" shows
%   the page of the bucket in the Collaboratory in a web browser.
%
%   A file whose name ends in ".sync-part" or ".multipart_manifest.json"
%   is not shown, whether it is in the folder or in the manifest: a
%   download is received in a file of the first kind next to its target,
%   and the ebrains-bucket-sync package keeps a manifest of the second
%   kind next to a file during a multipart upload, so such a file holds
%   no data of its own and remains only when a process is killed during
%   the transfer (see ebrains.bucket.sync.internal.isTransferLeftover). A
%   file given such a name on purpose is not shown either.
%
%   The browser is a web page in a uihtml component, and requires MATLAB
%   R2023a or later.
%
%   Input Arguments
%       localFolder : Folder of the virtual bucket
%
%   Name-Value Arguments
%       BucketName : Name of the bucket. Needed for a folder that is not a
%                    virtual bucket yet; for one that is, it must be the
%                    bucket of the folder.
%       Prefix     : Folder of the bucket that the virtual bucket holds,
%                    such as "results/", as given to createVirtualBucket.
%                    Paths below localFolder are relative to it. For a
%                    folder that is a virtual bucket already, it must be
%                    the prefix of the folder and may be left out. Default
%                    is "", the whole bucket, for a folder that is not.
%       Client     : ebrains.bucket.api.BucketsClient that sends the
%                    requests. Meant for tests and custom clients; a
%                    default client is created otherwise.
%       Downloader : Function that downloads a signed URL to a file, as
%                    for ebrains.bucket.downloadFile. Meant for tests.
%       Opener     : Function that is called with an address to open in
%                    a web browser. Meant for tests; WEB is called
%                    otherwise.
%       Confirmer  : Function that answers a confirmation, called as
%                    Confirmer(message, title, confirmText) and returning
%                    true to go on. Meant for tests; UICONFIRM asks
%                    otherwise.
%
%   Example:
%       ebrains.bucket.app.VirtualBucketBrowser("temp_data", ...
%           BucketName="d-ca602c23-364a-4c9b-943b-87d1b09a5821")
%       ebrains.bucket.app.VirtualBucketBrowser("temp_data")
%
%   See also ebrains.bucket.createVirtualBucket, ebrains.bucket.downloadFile,
%   ebrains.bucket.sync.fromBucket

    properties (SetAccess = private)
        % BucketName - Name of the bucket
        BucketName (1,1) string

        % LocalFolder - Absolute path of the folder of the virtual bucket
        LocalFolder (1,1) string

        % Prefix - Folder of the bucket that the virtual bucket holds
        Prefix (1,1) string

        % Files - State of each file, as ebrains.bucket.app.internal.classifyFiles returns it
        Files table

        % IsListed - Whether the files are compared with a listing of the bucket
        IsListed (1,1) logical = false

        % ListedTime - When the bucket was last listed, NaT if it never was
        ListedTime (1,1) datetime = NaT(TimeZone="UTC")

        % IsListedInSession - Whether the bucket was listed since the browser opened
        %
        % A listing read from the manifest may be old: an object may have
        % been removed since, and its downloaded file be the only copy.
        IsListedInSession (1,1) logical = false
    end

    properties (Access = private)
        Client ebrains.bucket.api.BucketsClient
        Downloader function_handle
        Opener function_handle
        Confirmer function_handle

        % LocalFiles - File table of the local folder, from the last scan
        LocalFiles table

        % RemoteFiles - File table of the last listing of the bucket, with
        % paths relative to LocalFolder. Empty if it was never listed.
        RemoteFiles = []

        % ChecksumCache - MD5 checksums of local files, by path
        %
        % containers.Map from a path to a struct with the Bytes and Time of
        % the file when its checksum was computed, and the Hash. The file
        % states need the checksum of a file whose time differs from its
        % object's, and reading large files again on every scan would be
        % slow. Created on first use, since a default value would be one
        % map shared by every browser.
        ChecksumCache = []

        % Message - Note on the last action, shown below the file list
        Message (1,1) string = ""

        % ListingPageSize - Objects asked for per request when the bucket is listed
        %
        % The time of a listing grows with the objects it returns (about
        % 30 ms each, as measured on the Data Proxy), not with the requests,
        % so pages of this size report progress about every half minute at
        % little extra cost.
        ListingPageSize (1,1) double = 1000

        % IsPageReady - Whether the page has loaded and can receive events
        IsPageReady (1,1) logical = false

        UIFigure matlab.ui.Figure
        Page matlab.ui.control.HTML
    end

    methods
        function app = VirtualBucketBrowser(localFolder, options)
            arguments
                localFolder string {mustBeScalarOrEmpty} = chooseFolder()
                options.BucketName (1,1) string = ""
                options.Prefix string {mustBeScalarOrEmpty} = string.empty
                options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
                options.Downloader (1,1) function_handle = @ebrains.external.webprogress.download
                options.Opener (1,1) function_handle = @web
                options.Confirmer function_handle {mustBeScalarOrEmpty} = function_handle.empty
            end

            % The folder dialog was cancelled: there is nothing to open
            if isempty(localFolder)
                return
            end
            if localFolder == ""
                error('EBRAINS:Bucket:InvalidFolder', 'Give the folder of the virtual bucket.')
            end

            % The page and MATLAB talk through events of the uihtml
            % component, which R2023a added. The check comes before the
            % folder is created, so an older release changes nothing.
            if isMATLABReleaseOlderThan("R2023a")
                error('EBRAINS:Bucket:UnsupportedRelease', ...
                    'The virtual bucket browser requires MATLAB R2023a or later.')
            end

            bucketInfo = ebrains.bucket.internal.metadata.readBucketInfo(localFolder);
            isNewVirtualBucket = isempty(bucketInfo);
            if isNewVirtualBucket
                if options.BucketName == ""
                    error('EBRAINS:Bucket:NotAVirtualBucket', ...
                        ['"%s" is not a virtual bucket. Give BucketName to make it one, ' ...
                         'or create one with ebrains.bucket.createVirtualBucket.'], localFolder)
                end
                prefix = "";
                if ~isempty(options.Prefix)
                    prefix = options.Prefix;
                end
                bucketInfo = struct("BucketName", options.BucketName, ...
                    "Prefix", ebrains.bucket.internal.normalizePrefix(prefix), ...
                    "ListedTime", NaT(TimeZone="UTC"));
            elseif options.BucketName ~= "" || ~isempty(options.Prefix)
                % A bucket or prefix that is left out is that of the folder
                bucketName = bucketInfo.BucketName;
                if options.BucketName ~= ""
                    bucketName = options.BucketName;
                end
                prefix = bucketInfo.Prefix;
                if ~isempty(options.Prefix)
                    prefix = options.Prefix;
                end
                refusal = ebrains.bucket.internal.metadata.otherBucketRefusal( ...
                    bucketInfo, bucketName, prefix);
                if refusal ~= ""
                    error('EBRAINS:Bucket:OtherBucket', '%s', refusal)
                end
            end

            isNewFolder = ~isfolder(localFolder);
            if isNewFolder
                mkdir(localFolder)
            end

            app.BucketName = bucketInfo.BucketName;
            app.LocalFolder = getAbsolutePath(localFolder);
            app.Prefix = bucketInfo.Prefix;
            app.ListedTime = bucketInfo.ListedTime;
            app.Client = options.Client;
            app.Downloader = options.Downloader;
            app.Opener = options.Opener;
            app.Confirmer = options.Confirmer;

            % A folder that is not a virtual bucket yet becomes one. One that
            % is already is only read, so that it can be on a read-only
            % location.
            if isNewVirtualBucket
                ebrains.bucket.internal.metadata.writeBucketInfo( ...
                    app.LocalFolder, app.BucketName, app.Prefix, app.ListedTime)
            end
            [manifestFiles, hasManifest] = ebrains.bucket.internal.metadata.readManifest(app.LocalFolder);
            if hasManifest
                % The manifest is written by whichever tool listed the
                % bucket last, and need not leave out the objects named
                % like the file of an interrupted transfer, as a listing of
                % this toolbox does (see
                % ebrains.bucket.sync.internal.isTransferLeftover). The
                % browser never shows such a file.
                isLeftover = ebrains.bucket.sync.internal.isTransferLeftover(manifestFiles.Path);
                app.RemoteFiles = manifestFiles(~isLeftover, :);
                app.IsListed = true;
            end

            app.scanLocalFolder()
            app.createComponents()

            if isNewFolder
                app.updateFromBucket()
            end

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end

        function refresh(app)
        % refresh - Read the local folder again and show the files as they are now
            app.scanLocalFolder()
            app.sendState()
        end

        function updateFromBucket(app)
        % updateFromBucket - List the bucket, add placeholders for new objects and compare
        %
        %   Objects that the folder has no file for get an empty
        %   placeholder, and the placeholders of objects removed since the
        %   last listing are deleted, each read again right before, so
        %   that one written into since the last scan is kept. Local files
        %   with data that the bucket does not have are kept.
            restoreControls = app.setBusy();  %#ok<NASGU>
            progressDialog = uiprogressdlg(app.UIFigure, Title="Update from bucket", ...
                Message=sprintf("Counting the objects of bucket ""%s""...", app.BucketName), ...
                Indeterminate="on", Cancelable="on");
            closeDialog = onCleanup(@() delete(progressDialog));

            try
                % The count comes from one request, which tells how long the
                % listing will take before it starts. It counts the whole
                % bucket, also when the virtual bucket holds a folder of it.
                nObjects = ebrains.bucket.getObjectCount(app.BucketName, Client=app.Client);
                progress = ebrains.bucket.app.internal.ListingProgress(progressDialog, nObjects, app.Prefix == "");
                progress.update(0)

                listedTime = datetime("now", TimeZone="UTC");
                remoteFiles = ebrains.bucket.sync.internal.listRemoteFiles( ...
                    app.BucketName, app.Prefix, app.Client, PageSize=app.ListingPageSize, ...
                    ProgressFcn=@(nListed, ~) progress.update(nListed));
            catch exception
                delete(closeDialog)
                if exception.identifier ~= "EBRAINS:Bucket:ListingCancelled"
                    uialert(app.UIFigure, exception.message, "Could not list the bucket")
                end
                return
            end

            progressDialog.Message = "Creating placeholders for new objects...";
            % On a file system that ignores case, an object whose name
            % differs only in case from a local file has that file already
            ignoreCase = ebrains.bucket.sync.internal.isCaseInsensitive(app.LocalFolder, app.LocalFiles.Path);
            isNew = ~ismember(matchKeys(remoteFiles.Path, ignoreCase), matchKeys(app.LocalFiles.Path, ignoreCase));
            % A path that something else is in the way of gets no
            % placeholder; the listing is recorded all the same, so the
            % manifest knows the object and the next update tries again
            pathsWithoutPlaceholder = ebrains.bucket.app.internal.createPlaceholderFiles( ...
                app.LocalFolder, remoteFiles.Path(isNew));

            % The folder stands for the bucket, so the placeholder of an
            % object removed since the last listing stands for nothing.
            % LocalFiles is the last scan, which may be old: a file that
            % was an empty placeholder then may hold data now, so each is
            % read again right before it is deleted, and kept if it does.
            removedFiles = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
            if app.IsListed
                removedFiles = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects( ...
                    app.LocalFiles, remoteFiles, app.RemoteFiles, IgnoreCase=ignoreCase);
            end
            isRemoved = false(height(removedFiles), 1);
            for i = 1:height(removedFiles)
                isRemoved(i) = ebrains.bucket.sync.internal.deletePlaceholder(app.LocalFolder, removedFiles.Path(i));
            end

            ebrains.bucket.internal.metadata.writeManifest(app.LocalFolder, remoteFiles)
            ebrains.bucket.internal.metadata.writeBucketInfo(app.LocalFolder, app.BucketName, app.Prefix, listedTime)

            app.RemoteFiles = remoteFiles;
            app.IsListed = true;
            app.IsListedInSession = true;
            app.ListedTime = listedTime;
            nAdded = sum(isNew) - numel(pathsWithoutPlaceholder);
            app.Message = "Added placeholders for " + countText(nAdded, "new object") + ".";
            if ~isempty(pathsWithoutPlaceholder)
                app.Message = app.Message + " " + countText(numel(pathsWithoutPlaceholder), "object") + ...
                    " got no placeholder, since a file, folder or symbolic link of the folder is in " + ...
                    "the way, for example """ + pathsWithoutPlaceholder(1) + """.";
            end
            if any(isRemoved)
                app.Message = app.Message + " Removed the placeholders of " + ...
                    countText(sum(isRemoved), "removed object") + ".";
            end
            if any(~isRemoved)
                app.Message = app.Message + " Kept " + countText(sum(~isRemoved), "file") + ...
                    " written into since the last scan, which the bucket no longer has.";
            end
            app.refresh()
        end
    end

    methods (Access = private) % Model
        function scanLocalFolder(app)
        % scanLocalFolder - Read the files of the local folder and give each a state
            localFiles = ebrains.bucket.sync.internal.listLocalFiles(app.LocalFolder);

            % Finder writes .DS_Store files into every folder it shows. They
            % belong to the file system, not to the bucket.
            isFinderFile = regexprep(localFiles.Path, "^.*/", "") == ".DS_Store";
            app.LocalFiles = localFiles(~isFinderFile, :);
            app.assignStates()
        end

        function rescanPaths(app, paths)
        % rescanPaths - Read the files of the given paths again, give each a state and show it
        %
        %   An action that discards local data must judge a file as it is
        %   now, not as it was at the last scan: the file may have been
        %   edited in another application since. Only the given files are
        %   read, since the state of a path rests on its own file and
        %   manifest entry alone, and the folder may stand for a bucket of
        %   many objects. On a file system that ignores case the row of a
        %   path is the one that matches it in any case.
            paths = unique(reshape(paths, [], 1));
            ignoreCase = ebrains.bucket.sync.internal.isCaseInsensitive(app.LocalFolder, app.LocalFiles.Path);
            isSelected = ismember(matchKeys(app.LocalFiles.Path, ignoreCase), matchKeys(paths, ignoreCase));
            readFiles = arrayfun(@(path) ebrains.bucket.sync.internal.listLocalFile(app.LocalFolder, path), ...
                paths, UniformOutput=false);
            app.LocalFiles = sortrows(vertcat(app.LocalFiles(~isSelected, :), readFiles{:}), "Path");
            app.assignStates()
            app.sendState()
        end

        function assignStates(app)
        % assignStates - Give each file of LocalFiles and of the manifest its state, in Files
            if ~app.IsListed
                app.Files = ebrains.bucket.app.internal.classifyFiles(app.LocalFiles);
                return
            end

            % On a file system that ignores case, a local file and an
            % object whose names differ only in case are one file, and of
            % objects that differ only in case only one can have a file.
            ignoreCase = ebrains.bucket.sync.internal.isCaseInsensitive(app.LocalFolder, app.LocalFiles.Path);
            remoteFiles = app.RemoteFiles;
            if ignoreCase
                remoteFiles = ebrains.bucket.sync.internal.dropCaseCollisions(remoteFiles);
            end
            app.Files = ebrains.bucket.app.internal.classifyFiles(app.LocalFiles, remoteFiles, ...
                IgnoreCase=ignoreCase, LocalHashFcn=@(path) app.localChecksum(path));
        end

        function hash = localChecksum(app, path)
        % localChecksum - MD5 checksum of a local file, read again only when its size or time changed
        %
        %   A file that cannot be read gives "", which leaves its state to
        %   its time.
            if isempty(app.ChecksumCache)
                app.ChecksumCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            file = app.LocalFiles(app.LocalFiles.Path == path, :);
            key = char(path);
            if isKey(app.ChecksumCache, key)
                cached = app.ChecksumCache(key);
                if cached.Bytes == file.Bytes && isequal(cached.Time, file.ModifiedTime)
                    hash = cached.Hash;
                    return
                end
            end

            try
                hash = ebrains.bucket.sync.internal.computeMD5(fullfile(app.LocalFolder, path));
            catch
                hash = "";
                return
            end
            app.ChecksumCache(key) = struct("Bytes", file.Bytes, "Time", file.ModifiedTime, "Hash", hash);
        end
    end

    methods (Access = private) % Actions
        function forgetChecksums(app, paths)
        % forgetChecksums - Drop the cached checksums of the given paths, so that the next scan reads the files
        %
        %   The cache takes a file with the size and time of its entry as
        %   unchanged, which a rewrite within the same time slot, or a
        %   restore that keeps the time, is not. An action that discards
        %   local data reads the files it is about to discard.
            if isempty(app.ChecksumCache)
                return
            end
            cachedPaths = string(keys(app.ChecksumCache));
            isSelected = ismember(lower(cachedPaths), lower(reshape(paths, [], 1)));
            if any(isSelected)
                remove(app.ChecksumCache, cellstr(cachedPaths(isSelected)));
            end
        end

        function downloadPaths(app, paths)
        % downloadPaths - Download the files of the given paths that are online only or differ
            % The files may have been edited since the last scan
            app.rescanPaths(paths)
            files = app.Files(ismember(app.Files.Path, paths), :);
            files = files(files.State == "online_only" | files.State == "differs", :);
            if isempty(files)
                uialert(app.UIFigure, "The selected files are downloaded already.", ...
                    "Nothing to download", Icon="info")
                return
            end

            nDiffering = sum(files.State == "differs");
            if nDiffering > 0
                message = sprintf(['%d of the files differ from the bucket. Downloading them ' ...
                    'replaces the local copies, and changes made to those copies are lost.'], nDiffering);
                if ~app.confirm(message, "Replace local copies?", "Download")
                    return
                end
            end

            % A file that cannot be downloaded does not stop the others: an
            % empty file is taken for a placeholder until the bucket is
            % listed, and it may not stand for any object. Only Cancel in
            % the progress dialog stops the batch.
            restoreControls = app.setBusy();  %#ok<NASGU>
            nFiles = height(files);
            failureMessages = strings(nFiles, 1);
            isFailed = false(nFiles, 1);
            isCancelled = false;
            for i = 1:nFiles
                relativePath = files.Path(i);
                try
                    app.downloadOne(relativePath)
                catch exception
                    isFailed(i) = true;
                    failureMessages(i) = exception.message;
                    if exception.identifier == "webprogress:download:Cancelled"
                        isCancelled = true;
                        break
                    end
                end
            end

            nDownloaded = sum(~isFailed(1:i));
            app.Message = "Downloaded " + countText(nDownloaded, "file") + ".";
            if nDownloaded < nFiles
                app.Message = sprintf("%d of %d files were downloaded.", nDownloaded, nFiles);
            end
            app.refresh()
            if isCancelled
                uialert(app.UIFigure, app.Message, "Download cancelled", Icon="info")
            elseif any(isFailed)
                uialert(app.UIFigure, failureReport(files.Path(isFailed), failureMessages(isFailed), nFiles), ...
                    "Some files were not downloaded")
            end
        end

        function downloadOne(app, relativePath)
        % downloadOne - Download an object into its file, as a sync from the bucket does
        %
        %   The file gets the size check and the time of its object that
        %   ebrains.bucket.sync.fromBucket gives a download, so that a
        %   later sync in either direction sees it as unchanged. Both come
        %   from the last listing; without one the download is only put in
        %   place. The file is replaced only while it is still as it was
        %   read when the download was decided.
            expectedBytes = NaN;
            modifiedTime = NaT;
            if app.IsListed
                [isListed, index] = ismember(relativePath, app.RemoteFiles.Path);
                if isListed
                    expectedBytes = app.RemoteFiles.Bytes(index);
                    modifiedTime = app.RemoteFiles.ModifiedTime(index);
                end
            end
            % The row of the file as the last scan read it; where the folder
            % ignores case the row may carry the name in another case.
            isRow = app.LocalFiles.Path == relativePath;
            if ~any(isRow)
                isRow = strcmpi(app.LocalFiles.Path, relativePath);
            end
            % A path from the manifest may lie below a folder that is a
            % symbolic link, whose files the scan left out; the download
            % would write outside the folder, so it is refused as in a sync
            ebrains.bucket.sync.internal.assertNotBelowLinkedFolder( ...
                app.LocalFolder, relativePath, app.Prefix + relativePath);
            ebrains.bucket.sync.internal.downloadAndReplace(app.BucketName, app.Prefix + relativePath, ...
                fullfile(app.LocalFolder, relativePath), ...
                ExpectedBytes=expectedBytes, ModifiedTime=modifiedTime, LocalFile=app.LocalFiles(isRow, :), ...
                DisplayMode="Dialog Box", Figure=app.UIFigure, Client=app.Client, ...
                Downloader=app.Downloader);
        end

        function makePathsOnlineOnly(app, paths)
        % makePathsOnlineOnly - Replace the downloaded files of the given paths with placeholders
            % The files may have been edited since the last scan, and a cached
            % checksum of a file rewritten within the same time slot would
            % hide the edit, so the files are read again in full.
            app.forgetChecksums(paths)
            app.rescanPaths(paths)
            files = app.Files(ismember(app.Files.Path, paths), :);

            nLocalOnly = sum(files.State == "local_only");
            files = files(files.State == "downloaded" | files.State == "differs", :);
            if isempty(files)
                if nLocalOnly > 0
                    message = ['The bucket does not have the selected files, so their ' ...
                        'local copies are the only ones and are kept.'];
                else
                    message = 'The selected files are online only already.';
                end
                uialert(app.UIFigure, message, "Nothing to make online only", Icon="info")
                return
            end

            % A file is replaced without asking only where a listing made
            % since the browser opened shows that its object exists and has
            % the size and time of the file, so it can be downloaded again.
            % Any other file may hold changes that exist nowhere else.
            nDiffering = sum(files.State == "differs");
            nUntimed = sum(isnat(files.LocalTime) | isnat(files.RemoteTime));
            freedBytes = formatBytes(sum(files.LocalBytes, "omitnan"));
            if ~app.IsListed
                message = sprintf(['Replace %d local files (%s) with empty placeholders? ' ...
                    'The bucket has not been listed, so the files cannot be checked against ' ...
                    'their objects. Changes made to the local copies are lost.'], ...
                    height(files), freedBytes);
            elseif nDiffering > 0
                message = sprintf(['%d of the %d files differ from the bucket. Replacing them ' ...
                    'with empty placeholders discards the local copies, and changes made to ' ...
                    'them are lost.'], nDiffering, height(files));
            elseif ~app.IsListedInSession
                message = sprintf(['Replace %d local files (%s) with empty placeholders? ' ...
                    'The files were compared with the listing of %s, and an object may have ' ...
                    'been removed or changed since. Update from bucket to check them. ' ...
                    'Changes made to the local copies are lost.'], ...
                    height(files), freedBytes, formatLocalTime(app.ListedTime));
            elseif nUntimed > 0
                message = sprintf(['%d of the %d files have no known time to compare with ' ...
                    'their objects, so a change made to them cannot be ruled out. Replacing ' ...
                    'them with empty placeholders discards the local copies.'], ...
                    nUntimed, height(files));
            else
                message = "";
            end
            if message ~= "" && ~app.confirm(message, "Make online only?", "Make online only")
                return
            end

            % The files are emptied only while they are still the files that
            % were judged, by the size and time they were judged by.
            judgedFiles = ebrains.bucket.sync.internal.makeFileTable(files.Path, files.LocalBytes, files.LocalTime);
            try
                ebrains.bucket.app.internal.replaceWithPlaceholders(app.LocalFolder, judgedFiles);
            catch exception
                app.refresh()
                uialert(app.UIFigure, exception.message, "Could not make the files online only")
                return
            end

            app.Message = "Freed " + freedBytes + " from " + countText(height(files), "file") + ".";
            if nLocalOnly > 0
                app.Message = app.Message + " Kept " + countText(nLocalOnly, "file") + ...
                    " that the bucket does not have.";
            end
            app.refresh()
        end

        function openPath(app, relativePath)
        % openPath - Open a file with the default application of the system
            state = app.Files.State(app.Files.Path == relativePath);
            if state == "online_only"
                message = sprintf("""%s"" is online only. Download it and open it?", relativePath);
                if ~app.confirm(message, "Download file?", "Download and open")
                    return
                end
                app.downloadPaths(relativePath)
                if app.Files.State(app.Files.Path == relativePath) == "online_only"
                    return
                end
            end
            app.runSystemCommand(openFileCommand(fullfile(app.LocalFolder, relativePath)))
        end

        function revealPath(app, relativePath)
        % revealPath - Show a file or folder in the file manager of the system
            app.runSystemCommand(revealCommand(fullfile(app.LocalFolder, relativePath)))
        end

        function openBucketOnline(app)
        % openBucketOnline - Show the page of the bucket in the Collaboratory in a web browser
            app.Opener(ebrains.bucket.internal.buildBucketViewURL(app.BucketName))
        end

        function runSystemCommand(app, command)
        % runSystemCommand - Run a command of the operating system, and report a failure
        %
        %   Explorer exits with status 1 when it succeeds, so the status of
        %   a command on Windows says nothing.
            [status, output] = system(command);
            if status ~= 0 && ~ispc
                uialert(app.UIFigure, output, "The command failed")
            end
        end

        function tf = confirm(app, message, title, confirmText)
        % confirm - Ask the user to confirm an action
            if ~isempty(app.Confirmer)
                tf = app.Confirmer(message, title, confirmText);
                return
            end
            selection = uiconfirm(app.UIFigure, message, title, ...
                Options=[confirmText, "Cancel"], DefaultOption=2, CancelOption=2, Icon="warning");
            tf = selection == confirmText;
        end
    end

    methods (Access = private) % Page
        function createComponents(app)
            app.UIFigure = uifigure(Name="Virtual bucket - " + app.BucketName, ...
                Position=[100 100 1100 680], CloseRequestFcn=@(~, ~) delete(app));
            grid = uigridlayout(app.UIFigure, [1 1], Padding=0);

            pageFile = fullfile(fileparts(mfilename("fullpath")), "resources", "virtualBucketBrowser.html");
            app.Page = uihtml(grid, HTMLSource=pageFile, ...
                HTMLEventReceivedFcn=@(~, event) app.onPageEvent(event));
        end

        function onPageEvent(app, event)
        % onPageEvent - Carry out a request of the page
        %
        %   The page sends its requests as JSON text: an object with the
        %   field "paths", the paths of the files or the folder the request
        %   is about.
        %
        %   The page can also draw confirm, alert and progress dialogs for
        %   a host that has none (see the protocol in its header). MATLAB
        %   has uiconfirm, uialert and uiprogressdlg and never asks for
        %   them, so the page never sends their replies here.
            request = jsondecode(event.HTMLEventData);
            paths = strings(0, 1);
            if isfield(request, "paths")
                paths = reshape(string(request.paths), [], 1);
            end

            try
                switch event.HTMLEventName
                    case "ready"
                        app.IsPageReady = true;
                        app.sendState()
                    case "refresh"
                        app.Message = "";
                        app.refresh()
                    case "update"
                        app.updateFromBucket()
                    case "download"
                        app.downloadPaths(paths)
                    case "onlineOnly"
                        app.makePathsOnlineOnly(paths)
                    case "open"
                        app.openPath(paths(1))
                    case "reveal"
                        app.revealPath(paths(1))
                    case "openOnline"
                        app.openBucketOnline()
                    otherwise
                        % The page sends no other requests to MATLAB
                end
            catch exception
                uialert(app.UIFigure, exception.message, "Something went wrong")
            end
        end

        function sendState(app)
        % sendState - Send the files and their states to the page
        %
        %   The state is sent as JSON text, encoded here, so that a single
        %   file still arrives as a list.
            if ~app.IsPageReady
                return
            end

            localTimes = app.Files.LocalTime;
            localTimes.TimeZone = "local";
            modifiedTexts = string(localTimes, "yyyy-MM-dd HH:mm");
            modifiedTexts(ismissing(modifiedTexts)) = "";

            state = struct( ...
                "bucketName", app.BucketName, ...
                "localFolder", app.LocalFolder, ...
                "prefix", app.Prefix, ...
                "isListed", app.IsListed, ...
                "listedAt", formatLocalTime(app.ListedTime), ...
                "revealLabel", revealActionName(), ...
                "message", app.Message, ...
                "files", struct( ...
                    "path", {cellstr(app.Files.Path)}, ...
                    "state", {cellstr(app.Files.State)}, ...
                    "localBytes", {num2cell(app.Files.LocalBytes)}, ...
                    "remoteBytes", {num2cell(app.Files.RemoteBytes)}, ...
                    "modified", {cellstr(modifiedTexts)}));
            sendEventToHTMLSource(app.Page, "state", jsonencode(state))
        end

        function restoreControls = setBusy(app)
        % setBusy - Disable the page until the returned object is deleted
            app.sendBusy(true)
            restoreControls = onCleanup(@() app.sendBusy(false));
        end

        function sendBusy(app, isBusy)
            if isvalid(app) && isvalid(app.Page) && app.IsPageReady
                sendEventToHTMLSource(app.Page, "busy", jsonencode(struct("busy", isBusy)))
            end
        end
    end
end

function folder = chooseFolder()
% chooseFolder - Ask for the folder of a virtual bucket; empty if the dialog is cancelled
    folder = uigetdir(pwd, "Choose the folder of the virtual bucket");
    if isequal(folder, 0)
        folder = string.empty;
    else
        folder = string(folder);
    end
end

function absolutePath = getAbsolutePath(folder)
% getAbsolutePath - Absolute path of an existing folder
    listing = dir(folder);
    absolutePath = string(listing(strcmp({listing.name}, '.')).folder);
end

function text = formatBytes(bytes)
% formatBytes - Size in bytes as text with a binary unit
    units = ["B", "KB", "MB", "GB", "TB"];
    exponent = min(max(floor(log(max(bytes, 1)) / log(1024)), 0), numel(units) - 1);
    if exponent == 0
        text = sprintf("%d B", bytes);
    else
        text = sprintf("%.1f %s", bytes / 1024^exponent, units(exponent + 1));
    end
end

function message = failureReport(failedPaths, failureMessages, nFiles)
% failureReport - Say which files of a batch could not be downloaded, and why
%
%   Only the first few are named, so that the alert stays readable.
    maxNamed = 5;
    nFailed = numel(failedPaths);
    nNamed = min(nFailed, maxNamed);
    lines = compose("""%s"": %s", failedPaths(1:nNamed), failureMessages(1:nNamed));
    message = sprintf("%d of %d files could not be downloaded:", nFailed, nFiles) + newline + newline + ...
        join(lines, newline + newline);
    if nFailed > nNamed
        message = message + newline + newline + sprintf("and %d more.", nFailed - nNamed);
    end
end

function text = formatLocalTime(time)
% formatLocalTime - Time in the local time zone, as the page shows it, or "" for NaT
    time.TimeZone = "local";
    text = string(time, "yyyy-MM-dd HH:mm");
    if ismissing(text)
        text = "";
    end
end

function keys = matchKeys(paths, ignoreCase)
% matchKeys - What paths are matched by, on a file system that ignores case or not
    keys = paths;
    if ignoreCase
        keys = lower(paths);
    end
end

function text = countText(count, noun)
% countText - Count followed by a noun, in the plural unless the count is one
    if count == 1
        text = "1 " + noun;
    else
        text = count + " " + noun + "s";
    end
end

function name = revealActionName()
    if ismac
        name = "Show in Finder";
    elseif ispc
        name = "Show in Explorer";
    else
        name = "Show in folder";
    end
end

function command = openFileCommand(filePath)
% openFileCommand - Command that opens a file with the default application of the system
    if ismac
        command = "open " + quoteForShell(filePath);
    elseif ispc
        command = "start """" """ + filePath + """";
    else
        command = "xdg-open " + quoteForShell(filePath);
    end
end

function command = revealCommand(absolutePath)
% revealCommand - Command that shows a file or folder in the file manager of the system
    if ismac
        command = "open -R " + quoteForShell(absolutePath);
    elseif ispc
        command = "explorer /select,""" + absolutePath + """";
    elseif isfolder(absolutePath)
        command = "xdg-open " + quoteForShell(absolutePath);
    else
        command = "xdg-open " + quoteForShell(fileparts(absolutePath));
    end
end

function quoted = quoteForShell(text)
% quoteForShell - Quote text as one argument of a POSIX shell
%
%   Nothing is special inside single quotes, so only a single quote itself
%   needs care: it ends the quoted text, is escaped, and starts it again.
    quoted = "'" + replace(text, "'", "'\''") + "'";
end
