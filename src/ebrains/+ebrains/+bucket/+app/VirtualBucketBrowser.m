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
%       ebrains.bucket.app.VirtualBucketBrowser(bucketName, localFolder)
%       opens the virtual bucket of bucketName in localFolder. If the
%       folder does not exist, it is created and filled with placeholders
%       from a listing of the bucket.
%
%       app = ebrains.bucket.app.VirtualBucketBrowser(...) also returns the
%       browser object.
%
%   The state of each file is judged from the local folder alone when the
%   browser opens: an empty file is online only and any other file is
%   downloaded. Listing a bucket of many objects takes a while, so the
%   bucket is listed only when "Update from bucket" is pressed. The update
%   adds placeholders for objects that the folder does not have yet, and
%   marks the files that differ from their objects and the files that the
%   bucket does not have.
%
%   The browser is a web page in a uihtml component, and requires MATLAB
%   R2023a or later.
%
%   Input Arguments
%       bucketName  : Name of the bucket
%       localFolder : Folder of the virtual bucket
%
%   Name-Value Arguments
%       Prefix     : Folder of the bucket that the virtual bucket holds,
%                    such as "results/", as given to createVirtualBucket.
%                    Paths below localFolder keep the prefix. Default is
%                    "", the whole bucket.
%       Client     : ebrains.bucket.api.BucketsClient that sends the
%                    requests. Meant for tests and custom clients; a
%                    default client is created otherwise.
%       Downloader : Function that downloads a signed URL to a file, as
%                    for ebrains.bucket.downloadFile. Meant for tests.
%
%   Example:
%       ebrains.bucket.app.VirtualBucketBrowser( ...
%           "d-ca602c23-364a-4c9b-943b-87d1b09a5821", "temp_data")
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

        % IsListed - Whether the files have been compared with a listing of the bucket
        IsListed (1,1) logical = false
    end

    properties (Access = private)
        Client ebrains.bucket.api.BucketsClient
        Downloader function_handle

        % LocalFiles - File table of the local folder, from the last scan
        LocalFiles table

        % RemoteFiles - File table of the bucket, with paths relative to
        % LocalFolder, from the last update. Empty until the first update.
        RemoteFiles = []

        % Message - Note on the last action, shown below the file list
        Message (1,1) string = ""

        % IsPageReady - Whether the page has loaded and can receive events
        IsPageReady (1,1) logical = false

        UIFigure matlab.ui.Figure
        Page matlab.ui.control.HTML
    end

    methods
        function app = VirtualBucketBrowser(bucketName, localFolder, options)
            arguments
                bucketName (1,1) string {mustBeNonzeroLengthText}
                localFolder (1,1) string {mustBeNonzeroLengthText}
                options.Prefix (1,1) string {mustBeFolderPrefix} = ""
                options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
                options.Downloader (1,1) function_handle = @ebrains.external.webprogress.download
            end

            isNewFolder = ~isfolder(localFolder);
            if isNewFolder
                mkdir(localFolder)
            end

            app.BucketName = bucketName;
            app.LocalFolder = getAbsolutePath(localFolder);
            app.Prefix = options.Prefix;
            app.Client = options.Client;
            app.Downloader = options.Downloader;

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
        %   placeholder. Local files that the bucket does not have are kept.
            restoreControls = app.setBusy();  %#ok<NASGU>
            progressDialog = uiprogressdlg(app.UIFigure, Title="Update from bucket", ...
                Message=sprintf("Listing the objects of bucket ""%s""...", app.BucketName), ...
                Indeterminate="on");
            closeDialog = onCleanup(@() delete(progressDialog));

            try
                remoteFiles = ebrains.bucket.sync.internal.listRemoteFiles( ...
                    app.BucketName, app.Prefix, app.Client);
            catch exception
                delete(closeDialog)
                uialert(app.UIFigure, exception.message, "Could not list the bucket")
                return
            end
            remoteFiles.Path = app.Prefix + remoteFiles.Path;

            progressDialog.Message = "Creating placeholders for new objects...";
            isNew = ~ismember(remoteFiles.Path, app.LocalFiles.Path);
            ebrains.bucket.app.internal.createPlaceholderFiles(app.LocalFolder, remoteFiles.Path(isNew));

            app.RemoteFiles = remoteFiles;
            app.IsListed = true;
            app.Message = "Compared with the bucket. Added placeholders for " + countText(sum(isNew), "new object") + ".";
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

            if app.IsListed
                % Only the files below the prefix were listed, so only
                % those can be compared with the bucket.
                isBelowPrefix = startsWith(app.LocalFiles.Path, app.Prefix);
                files = [ ...
                    ebrains.bucket.app.internal.classifyFiles(app.LocalFiles(isBelowPrefix, :), app.RemoteFiles); ...
                    ebrains.bucket.app.internal.classifyFiles(app.LocalFiles(~isBelowPrefix, :))];
                app.Files = sortrows(files, "Path");
            else
                app.Files = ebrains.bucket.app.internal.classifyFiles(app.LocalFiles);
            end
        end
    end

    methods (Access = private) % Actions
        function downloadPaths(app, paths)
        % downloadPaths - Download the files of the given paths that are online only or differ
            files = app.Files(ismember(app.Files.Path, paths), :);
            files = files(files.State == "OnlineOnly" | files.State == "Differs", :);
            if isempty(files)
                uialert(app.UIFigure, "The selected files are downloaded already.", ...
                    "Nothing to download", Icon="info")
                return
            end

            nDiffering = sum(files.State == "Differs");
            if nDiffering > 0
                message = sprintf(['%d of the files differ from the bucket. Downloading them ' ...
                    'replaces the local copies, and changes made to those copies are lost.'], nDiffering);
                if ~app.confirm(message, "Replace local copies?", "Download")
                    return
                end
            end

            restoreControls = app.setBusy();  %#ok<NASGU>
            nFiles = height(files);
            for i = 1:nFiles
                path = files.Path(i);
                try
                    ebrains.bucket.downloadFile(app.BucketName, path, fullfile(app.LocalFolder, path), ...
                        DisplayMode="Dialog Box", Figure=app.UIFigure, Client=app.Client, ...
                        Downloader=app.Downloader);
                catch exception
                    app.Message = sprintf("%d of %d files were downloaded.", i - 1, nFiles);
                    app.refresh()
                    message = sprintf("%d of %d files were downloaded. ""%s"" could not be downloaded:\n\n%s", ...
                        i - 1, nFiles, path, exception.message);
                    uialert(app.UIFigure, message, "Download stopped")
                    return
                end
            end
            app.Message = "Downloaded " + countText(nFiles, "file") + ".";
            app.refresh()
        end

        function makePathsOnlineOnly(app, paths)
        % makePathsOnlineOnly - Replace the downloaded files of the given paths with placeholders
            files = app.Files(ismember(app.Files.Path, paths), :);

            nLocalOnly = sum(files.State == "LocalOnly");
            files = files(files.State == "Downloaded" | files.State == "Differs", :);
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

            % A file that matches its object can be downloaded again, so it
            % is replaced without asking. Any other file may hold changes
            % that exist nowhere else.
            nDiffering = sum(files.State == "Differs");
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
            else
                message = "";
            end
            if message ~= "" && ~app.confirm(message, "Make online only?", "Make online only")
                return
            end

            try
                ebrains.bucket.app.internal.replaceWithPlaceholders(app.LocalFolder, files.Path);
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

        function openPath(app, path)
        % openPath - Open a file with the default application of the system
            state = app.Files.State(app.Files.Path == path);
            if state == "OnlineOnly"
                message = sprintf("""%s"" is online only. Download it and open it?", path);
                if ~app.confirm(message, "Download file?", "Download and open")
                    return
                end
                app.downloadPaths(path)
                if app.Files.State(app.Files.Path == path) == "OnlineOnly"
                    return
                end
            end
            app.runSystemCommand(openFileCommand(fullfile(app.LocalFolder, path)))
        end

        function revealPath(app, path)
        % revealPath - Show a file or folder in the file manager of the system
            app.runSystemCommand(revealCommand(fullfile(app.LocalFolder, path)))
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
                    otherwise
                        % The page sends no other events
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

function mustBeFolderPrefix(prefix)
% mustBeFolderPrefix - Validate that a prefix is empty or names a folder
    if prefix ~= "" && ~endsWith(prefix, "/")
        error('EBRAINS:Bucket:InvalidPrefix', ...
            'The prefix "%s" must end with "/", as the name of a folder of the bucket does.', prefix)
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

function command = revealCommand(path)
% revealCommand - Command that shows a file or folder in the file manager of the system
    if ismac
        command = "open -R " + quoteForShell(path);
    elseif ispc
        command = "explorer /select,""" + path + """";
    elseif isfolder(path)
        command = "xdg-open " + quoteForShell(path);
    else
        command = "xdg-open " + quoteForShell(fileparts(path));
    end
end

function quoted = quoteForShell(text)
% quoteForShell - Quote text as one argument of a POSIX shell
%
%   Nothing is special inside single quotes, so only a single quote itself
%   needs care: it ends the quoted text, is escaped, and starts it again.
    quoted = "'" + replace(text, "'", "'\''") + "'";
end
