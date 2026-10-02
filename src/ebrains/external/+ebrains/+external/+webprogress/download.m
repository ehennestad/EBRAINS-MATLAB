function savedFilePath = download(targetPath, url, options)
%download - Download a file from the web and display progress
%   ebrains.external.webprogress.download(FILENAME,URL) downloads the file at URL and
%   saves it to FILENAME exactly, without adding an extension, and
%   replaces an existing file. Progress is shown in a waitbar.
%   Percent-encoded characters in URL, such as %20, are sent unchanged.
%
%   If FILENAME is a folder, the file is saved in that folder under the
%   name the server gives in its Content-Disposition header, or else
%   under the last segment of the URL path.
%
%   The file is received in a temporary file in the target folder, which
%   replaces the target only after a successful download. If the
%   download fails or is interrupted, an existing file is left unchanged.
%
%   FILEPATH = ebrains.external.webprogress.download(FILENAME,URL) also returns the full
%   path of the saved file.
%
%   [...] = ebrains.external.webprogress.download(...,DisplayMode=MODE) specifies where
%   progress is shown. MODE must be:
%       "Dialog Box"     - (default) Shows progress in a dialog box.
%       "Command Window" - Prints progress in the Command Window.
%       "None"           - Shows nothing. Use it with ProgressFcn to show
%                          progress in a display of your own.
%
%   [...] = ebrains.external.webprogress.download(...,UpdateInterval=SECONDS) specifies
%   the minimum number of seconds between progress updates. The default
%   is 1.
%
%   [...] = ebrains.external.webprogress.download(...,ShowFilename=SHOW) shows the file
%   name from URL in the progress title when SHOW is true. The default
%   is false.
%
%   [...] = ebrains.external.webprogress.download(...,Filename=NAME) shows NAME in the
%   progress title, whether SHOW is true or false. Use it when the last
%   segment of URL is not the name to show, for example an identifier.
%   The default is '', which leaves the title to ShowFilename.
%
%   [...] = ebrains.external.webprogress.download(...,IndentSize=N) indents progress
%   printed in the Command Window by N spaces. The default is 0.
%
%   [...] = ebrains.external.webprogress.download(...,Figure=FIG) shows progress in a
%   uiprogressdlg in the figure FIG. Before R2025a, FIG must be a
%   uifigure. For other figures, progress is shown in a waitbar.
%
%   [...] = ebrains.external.webprogress.download(...,FileSizeBytes=N) specifies the file
%   size in bytes to use for progress when the server does not report it.
%
%   [...] = ebrains.external.webprogress.download(...,ProgressFcn=FCN) calls FCN with the
%   progress of the download, at most once per UpdateInterval and once
%   more when it is done. FCN receives a struct with the fields
%   ActionName ("Download"), TransferredBytes and TotalBytes. Both byte
%   counts include the part of a resumed download already received.
%   TotalBytes is NaN when the size is unknown.
%
%   [...] = ebrains.external.webprogress.download(...,CancelRequestedFcn=FCN) calls FCN
%   before the download and at most once per UpdateInterval while it
%   runs. When FCN returns true, the download stops and
%   ebrains.external.webprogress.download raises the error webprogress:download:Cancelled.
%   No file is saved, but with Resume=true the part received so far is
%   kept, so a later call can continue from it. The Cancel button of the
%   progress dialog stops the download in the same way.
%
%   [...] = ebrains.external.webprogress.download(...,Resume=TF) keeps the part of the file
%   received so far when the download fails or is interrupted, and
%   continues from it on a later call when TF is true. The default is
%   false. FILENAME must be a file path, not a folder. The part is kept
%   in FILENAME + ".part", and the ETag and length of the file it belongs
%   to in FILENAME + ".part.json". A later call with Resume=true asks the
%   server for the rest of that file only, so URL may differ between
%   calls, as a presigned URL does. If the file has changed on the
%   server, or the server cannot send part of a file, the download starts
%   from the beginning. The same happens when the server gives the file
%   no ETag or a weak one. Both files are deleted after a successful
%   download. Two MATLAB sessions that download to the same FILENAME
%   with Resume=true write the same partial file and corrupt it.
%
%   ebrains.external.webprogress.download raises an error if the server responds with a
%   status that is not a successful 2xx status, if the connection closes
%   before the number of bytes the server announced in its
%   Content-Length header has arrived, or if the server announces
%   different lengths in several Content-Length headers. In each case no
%   file is saved. With Resume=true, the part received before the error
%   is kept.
%
%   Example: Download a file and print progress in the Command Window
%       url = "https://allen-brain-observatory.s3.us-west-2" + ...
%           ".amazonaws.com/visual-coding-2p/stimulus_mappings.json";
%       filePath = ebrains.external.webprogress.download(tempdir, url, ...
%           "DisplayMode", "Command Window");
%
%   See also ebrains.external.webprogress.upload, websave

%   Written by Eivind Hennestad

    arguments
        targetPath             char         {mustBeNonempty}
        url                    char         {mustBeValidUrl}
        options.DisplayMode    char         {mustBeValidDisplay} = 'Dialog Box'
        options.UpdateInterval (1,1) double {mustBePositive}     = 1
        options.ShowFilename   (1,1) logical                     = false
        options.Filename       (1,:) char                        = ''
        options.IndentSize     (1,1) uint8                       = 0
        options.Figure         {mustBeFigureOrEmpty}             = []
        options.FileSizeBytes  (1,1) double                      = nan
        options.Resume         (1,1) logical                     = false
        options.ProgressFcn    {mustBeFunctionHandleOrEmpty}     = []
        options.CancelRequestedFcn {mustBeFunctionHandleOrEmpty} = []
    end

    isCancelRequested = options.CancelRequestedFcn;
    raiseIfCancelled(isCancelRequested)

    % The URL is already percent-encoded, as any URL handed out by a web
    % service is. Without 'literal' the URI constructor would encode it a
    % second time ("%20" would become "%2520") and the server would
    % reject every name with a space or other encoded character.
    uri = matlab.net.URI(url, 'literal');

    if ~isempty(options.Filename)
        filename = options.Filename;
    elseif options.ShowFilename && ~isempty(uri.Path)
        % URI.Path holds the decoded path segments and excludes the query,
        % which for a signed URL carries the signature.
        filename = char(uri.Path(end));
    else
        filename = '';
    end

    monitorOpts = {...
        'DisplayMode', options.DisplayMode, ...
        'UpdateInterval', options.UpdateInterval, ...
        'Filename', filename, ...
        'IndentSize', options.IndentSize, ...
        'Figure', options.Figure, ...
        'FileSizeBytes', options.FileSizeBytes, ...
        'ProgressFcn', options.ProgressFcn, ...
        'CancelRequestedFcn', options.CancelRequestedFcn };
    
    isFolderTarget = isfolder(targetPath);
    if isFolderTarget
        if options.Resume
            error("webprogress:download:FolderTargetNotResumable", ...
                "Cannot resume a download into the folder ""%s"", because the file name " + ...
                "is known only after the download starts. Give the path of the file " + ...
                "to write instead of a folder.", targetPath)
        end
        targetFolder = targetPath;
    else
        targetFolder = fileparts(targetPath);
        if isempty(targetFolder)
            targetFolder = pwd;
        end
        if ~isfolder(targetFolder)
            error("webprogress:download:FolderNotFound", ...
                "Cannot save the file because the folder ""%s"" does not exist. " + ...
                "Create the folder or choose another file path.", targetFolder)
        end
    end

    [~, folderInfo] = fileattrib(targetFolder);
    targetFolder = folderInfo.Name; % Full path, also for a relative input

    if options.Resume
        [~, name, ext] = fileparts(targetPath);
        targetName = string(name) + string(ext);
        receivedFile = string(fullfile(targetFolder, targetName)) + ".part";
        stateFile = receivedFile + ".json";
        receiveResumable(uri, receivedFile, stateFile, monitorOpts, isCancelRequested)
    else
        % Receive the file in a temporary file that replaces the target
        % only after a successful download, so an existing file survives a
        % failed or interrupted download. The file consumer writes the
        % response body whatever the status, and it overwrites its target
        % as soon as data arrives. The temporary file sits in the target
        % folder so that the final move is a rename, not a copy. Its .part
        % extension stops the file consumer from adding an extension of
        % its own, such as ".txt" for a text/plain response. onCleanup
        % deletes the temporary file when the function exits early,
        % including by an error or Ctrl+C.
        receivedFile = [tempname(targetFolder), '.part'];
        temporaryFileCleanup = onCleanup(@() deleteIfFile(receivedFile));
        consumer = matlab.net.http.io.FileConsumer(receivedFile);

        webOpts = createHttpOptions(@(varargin) ...
            ebrains.external.webprogress.FileTransferProgressMonitor(monitorOpts{:}));
        method = matlab.net.http.RequestMethod.GET;
        req = matlab.net.http.RequestMessage(method, [], []);

        resp = sendRequest(req, uri, webOpts, consumer, isCancelRequested);

        if resp.StatusCode.getClass() ~= matlab.net.http.StatusClass.Successful
            raiseRequestFailed(resp)
        end

        assertCompleteTransfer(resp, receivedFile)

        if isFolderTarget
            targetName = getRemoteFilename(resp, uri);
            if strlength(targetName) == 0
                error("webprogress:download:NoFilename", ...
                    "Cannot name the downloaded file because neither the server " + ...
                    "response nor the URL gives a file name. Give the path of the " + ...
                    "file to write instead of a folder.")
            end
        else
            [~, name, ext] = fileparts(targetPath);
            targetName = string(name) + string(ext);
        end
    end

    % The consumer creates its file when the first data arrives, so a
    % response with an empty body leaves no file to move.
    if ~isfile(receivedFile)
        fclose(fopen(receivedFile, 'w'));
    end

    targetFile = string(fullfile(targetFolder, targetName));
    [isMoved, moveMessage] = movefile(receivedFile, targetFile, 'f');
    if ~isMoved
        error("webprogress:download:CannotSaveFile", ...
            "Cannot save the downloaded file as ""%s"": %s", targetFile, moveMessage)
    end

    if options.Resume
        deleteIfFile(stateFile)
    end

    savedFilePath = targetFile;

    if nargout < 1
        clear savedFilePath
    end
end

function webOpts = createHttpOptions(progressMonitorFcn)
    %createHttpOptions - Return the HTTP options of a download
    webOpts = matlab.net.http.HTTPOptions(...
        'ProgressMonitorFcn', progressMonitorFcn, ...
        'UseProgressMonitor', true, ...
        'ConnectTimeout', 20);
end

function response = sendRequest(req, uri, webOpts, consumer, isCancelRequested)
    %sendRequest - Send a request, and raise an error if it was cancelled
    %   The progress monitor stops a cancelled transfer with an error. A
    %   cancel requested after its last report is found once the
    %   transfer is done. Either way the caller gets the Cancelled error.
    try
        response = req.send(uri, webOpts, consumer);
    catch exception
        if isCancellation(exception)
            raiseCancelled()
        end
        raiseIfCancelled(isCancelRequested)
        rethrow(exception)
    end
    raiseIfCancelled(isCancelRequested)
end

function raiseIfCancelled(isCancelRequested)
    %raiseIfCancelled - Raise an error if CancelRequestedFcn asks to stop
    if ~isempty(isCancelRequested) && isCancelRequested()
        raiseCancelled()
    end
end

function raiseCancelled()
    %raiseCancelled - Raise the error for a cancelled download
    error("webprogress:download:Cancelled", ...
        "The download was cancelled.")
end

function raiseRequestFailed(response)
    %raiseRequestFailed - Raise the error for a response with a failed status
    error("webprogress:download:RequestFailed", ...
        "Download failed because the server responded with ""%s"". " + ...
        "Check that the URL is correct and has not expired.", ...
        string(response.StatusLine))
end

function receiveResumable(uri, partialFile, stateFile, monitorOpts, isCancelRequested)
    %receiveResumable - Receive a file into a partial file that survives failures
    %   The request asks for the bytes after those in partialFile when
    %   stateFile holds the strong entity tag of the file they came from.
    %   The consumer checks that a 206 response continues that file,
    %   because a server may ignore If-Range and send a range of a
    %   changed file. When it does not, or the range cannot be satisfied
    %   because the partial file is longer than the file on the server,
    %   both files are deleted and the download starts from the
    %   beginning with a second request. Any status other than 200, 206
    %   or 416 leaves both files unchanged.
    [entityTag, totalBytes] = readState(stateFile);
    offset = 0;
    if strlength(entityTag) > 0 && isfile(partialFile)
        fileInfo = dir(partialFile);
        offset = fileInfo.bytes;
    end

    isRestartRequired = false;
    try
        [response, consumer] = sendResumableRequest(uri, partialFile, stateFile, ...
            offset, entityTag, totalBytes, monitorOpts, isCancelRequested);
    catch exception
        if exception.identifier ~= "webprogress:download:RestartRequired"
            rethrow(exception)
        end
        isRestartRequired = true;
    end

    % 416 answers a range that starts at or past the end of the file. A
    % partial file as long as the file it came from already holds the
    % whole file. The length comes from the state file, because a 416
    % response need not carry Content-Range (RFC 9110, section 15.5.17).
    if ~isRestartRequired && double(response.StatusCode) == 416 && offset > 0
        if offset == totalBytes
            return
        end
        isRestartRequired = true;
    end

    if isRestartRequired
        deleteIfFile(partialFile)
        deleteIfFile(stateFile)
        [response, consumer] = sendResumableRequest(uri, partialFile, stateFile, ...
            0, "", nan, monitorOpts, isCancelRequested);
    end

    if ~any(double(response.StatusCode) == [200, 206])
        raiseRequestFailed(response)
    end

    assertCompleteResumable(partialFile, consumer.ExpectedBytes, consumer.TotalBytes)
end

function [response, consumer] = sendResumableRequest(uri, partialFile, stateFile, ...
        offset, entityTag, totalBytes, monitorOpts, isCancelRequested)
    %sendResumableRequest - Send a GET request for the bytes from offset onward
    %   An offset of 0 asks for the whole file. Accept-Encoding asks for
    %   the file without a content coding, because a byte range counts
    %   the bytes as sent (RFC 9110, sections 12.5.3 and 14.1), and the
    %   HTTP client otherwise asks for gzip. If-Range lets a server that
    %   honours it send the whole file instead of a range when the
    %   entity tag no longer matches (section 13.1.5).
    consumer = ebrains.external.webprogress.internal.ResumableFileConsumer(partialFile, stateFile, ...
        offset, entityTag, totalBytes);
    webOpts = createHttpOptions(@(varargin) createResumeMonitor(consumer, monitorOpts));

    fields = matlab.net.http.HeaderField("Accept-Encoding", "identity");
    if offset > 0
        fields = [fields, ...
            matlab.net.http.HeaderField("Range", sprintf("bytes=%d-", offset)), ...
            matlab.net.http.HeaderField("If-Range", entityTag)];
    end
    method = matlab.net.http.RequestMethod.GET;
    req = matlab.net.http.RequestMessage(method, fields, []);

    response = sendRequest(req, uri, webOpts, consumer, isCancelRequested);
end

function monitor = createResumeMonitor(consumer, monitorOpts)
    %createResumeMonitor - Create a progress monitor and hand it to the consumer
    %   The consumer sets the StartBytes of the monitor once the response
    %   status shows whether the body continues the partial file or
    %   replaces it.
    monitor = ebrains.external.webprogress.FileTransferProgressMonitor(monitorOpts{:});
    consumer.ProgressMonitor = monitor;
end

function [entityTag, totalBytes] = readState(stateFile)
    %readState - Return the entity tag and length saved in a state file
    %   The entity tag is "" and the length NaN when the file is missing
    %   or cannot be read, as after an interruption while it was written.
    %   A weak entity tag cannot tell whether two responses carry the
    %   same bytes (RFC 9110, section 8.8.3), so it counts as none.
    entityTag = "";
    totalBytes = nan;
    if ~isfile(stateFile)
        return
    end
    try
        state = jsondecode(fileread(stateFile));
    catch
        return
    end
    if ~isstruct(state) || ~isfield(state, 'ETag') || ~isfield(state, 'TotalBytes') ...
            || ~(ischar(state.ETag) || isstring(state.ETag)) || ~isnumeric(state.TotalBytes)
        return
    end
    savedETag = strtrim(string(state.ETag));
    if strlength(savedETag) == 0 || startsWith(savedETag, "W/")
        return
    end
    entityTag = savedETag;
    totalBytes = double(state.TotalBytes);
end

function assertCompleteResumable(partialFile, expectedBytes, totalBytes)
    %assertCompleteResumable - Raise an error if the partial file is not complete
    %   expectedBytes is the size of the partial file after the whole
    %   body, and totalBytes the length of the complete file. For a 206
    %   response both come from Content-Range, and the body may end before
    %   the complete length when the server does not know it ("*") or
    %   sends less than the rest of the file. For a 200 response both are
    %   the Content-Length. Either is NaN when the response does not give
    %   it, and a transfer that neither describes cannot be checked.
    receivedBytes = 0;
    if isfile(partialFile)
        fileInfo = dir(partialFile);
        receivedBytes = fileInfo.bytes;
    end

    if ~isnan(totalBytes) && receivedBytes ~= totalBytes
        error("webprogress:download:IncompleteTransfer", ...
            "The download stopped after %d of %d bytes. The part received is kept " + ...
            "in ""%s"". Call ebrains.external.webprogress.download again with Resume=true to continue.", ...
            receivedBytes, totalBytes, partialFile)
    elseif isnan(totalBytes) && ~isnan(expectedBytes) && receivedBytes ~= expectedBytes
        error("webprogress:download:IncompleteTransfer", ...
            "The download stopped after %d bytes, before the %d bytes the server sent " + ...
            "had arrived. The part received is kept in ""%s"". Call " + ...
            "ebrains.external.webprogress.download again with Resume=true to continue.", ...
            receivedBytes, expectedBytes, partialFile)
    end
end

function assertCompleteTransfer(response, filePath)
    %assertCompleteTransfer - Raise an error if the body is shorter than announced
    %   The HTTP client ends a transfer without an error when the server
    %   closes the connection early, so a dropped connection would save a
    %   truncated file. The size of the received file is compared with the
    %   Content-Length of the response. Without that header, as for a
    %   chunked response, there is nothing to compare with. A body with a
    %   content coding such as gzip is decoded while it is saved, so its
    %   saved size differs from Content-Length and is not compared.
    declaredBytes = ebrains.external.webprogress.internal.getDeclaredLength(response);
    if isnan(declaredBytes) || ~ebrains.external.webprogress.internal.hasIdentityEncoding(response)
        return
    end

    receivedBytes = 0;
    if isfile(filePath)
        fileInfo = dir(filePath);
        receivedBytes = fileInfo.bytes;
    end
    if receivedBytes ~= declaredBytes
        error("webprogress:download:IncompleteTransfer", ...
            "The download stopped after %d of %d bytes, so the file was not saved. " + ...
            "Download it again. If it stops again, check the network connection.", ...
            receivedBytes, declaredBytes)
    end
end

function filename = getRemoteFilename(response, uri)
    %getRemoteFilename - Return the file name given by the server or the URL
    %   The Content-Disposition file name takes precedence, as in the file
    %   consumer. Only its last component is kept, because the server
    %   controls it and folder parts such as "../" would write outside the
    %   target folder. The result is "" when there is no usable name.
    filename = "";

    dispositionField = response.getFields("Content-Disposition");
    if ~isempty(dispositionField)
        filename = dispositionField(end).getParameter("filename");
    end

    if (isempty(filename) || strlength(filename) == 0) && ~isempty(uri.Path)
        filename = uri.Path(end);
    end

    if isempty(filename)
        filename = "";
    end

    [~, name, ext] = fileparts(string(filename));
    filename = name + ext;
    if any(filename == [".", ".."])
        filename = "";
    end
end

function deleteIfFile(filePath)
    %deleteIfFile - Delete a file if it exists
    if isfile(filePath)
        delete(filePath)
    end
end
