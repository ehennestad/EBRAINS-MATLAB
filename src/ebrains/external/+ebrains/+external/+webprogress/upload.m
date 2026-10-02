function [wasSuccess, response] = upload(filePath, url, options)
%upload - Upload a file to the web and display progress
%   ebrains.external.webprogress.upload(FILENAME,URL) uploads the file FILENAME to URL
%   with a PUT request and shows progress in a waitbar. Percent-encoded
%   characters in URL, such as %20, are sent unchanged.
%   ebrains.external.webprogress.upload raises an error if the server responds with a
%   status that is not a successful 2xx status.
%
%   TF = ebrains.external.webprogress.upload(FILENAME,URL) returns true if the server
%   responds with a successful 2xx status and false otherwise. With an
%   output, ebrains.external.webprogress.upload does not raise an error for an
%   unsuccessful status.
%
%   [TF,RESPONSE] = ebrains.external.webprogress.upload(FILENAME,URL) also returns the
%   response message from the server.
%
%   [...] = ebrains.external.webprogress.upload(...,DisplayMode=MODE) specifies where
%   progress is shown. MODE must be:
%       "Dialog Box"     - (default) Shows progress in a dialog box.
%       "Command Window" - Prints progress in the Command Window.
%       "None"           - Shows nothing. Use it with ProgressFcn to show
%                          progress in a display of your own.
%
%   [...] = ebrains.external.webprogress.upload(...,UpdateInterval=SECONDS) specifies the
%   minimum number of seconds between progress updates. The default is 1.
%
%   [...] = ebrains.external.webprogress.upload(...,ShowFilename=SHOW) shows the name of
%   FILENAME in the progress title when SHOW is true. The default is
%   false.
%
%   [...] = ebrains.external.webprogress.upload(...,Filename=NAME) shows NAME in the
%   progress title, whether SHOW is true or false. Use it when the file is
%   stored under another name than the local file has. The default is '',
%   which leaves the title to ShowFilename.
%
%   [...] = ebrains.external.webprogress.upload(...,IndentSize=N) indents progress printed
%   in the Command Window by N spaces. The default is 0.
%
%   [...] = ebrains.external.webprogress.upload(...,Figure=FIG) shows progress in a
%   uiprogressdlg in the figure FIG. Before R2025a, FIG must be a
%   uifigure. For other figures, progress is shown in a waitbar.
%
%   [...] = ebrains.external.webprogress.upload(...,RequestMessage=REQUEST) sends REQUEST
%   instead of a PUT request, for example to use another method or to add
%   headers. The body of REQUEST is replaced by the file.
%
%   [...] = ebrains.external.webprogress.upload(...,Offset=N) sends the file from N bytes
%   into it, instead of from its first byte. The default is 0.
%
%   [...] = ebrains.external.webprogress.upload(...,NumBytes=N) sends N bytes of the file.
%   The default is Inf, which sends the file to its end. With Offset or
%   NumBytes, the request carries no header that names the range, and
%   the Content-Type is not taken from the file. Add the headers that
%   the service expects, such as a Content-Type, with RequestMessage.
%   Use Offset and NumBytes to send one part of a file that a storage
%   service receives in several requests.
%
%   [...] = ebrains.external.webprogress.upload(...,ProgressFcn=FCN) calls FCN with the
%   progress of the upload, at most once per UpdateInterval and once more
%   when it is done. FCN receives a struct with the fields ActionName
%   ("Upload"), TransferredBytes and TotalBytes.
%
%   [...] = ebrains.external.webprogress.upload(...,CancelRequestedFcn=FCN) calls FCN
%   before the upload and at most once per UpdateInterval while it runs.
%   When FCN returns true, the upload stops and ebrains.external.webprogress.upload raises
%   the error webprogress:upload:Cancelled, also when it has outputs. The
%   Cancel button of the progress dialog stops the upload in the same way.
%
%   [...] = ebrains.external.webprogress.upload(...,ProgressMonitor=MONITOR) shows
%   progress in MONITOR, a ebrains.external.webprogress.MultipartProgressMonitor, which
%   stays open after the upload. Pass the same monitor to the upload of
%   each part of a file to show the progress of the whole file. A part
%   that the server accepts is added to MONITOR.CompletedBytes. The
%   display options of ebrains.external.webprogress.upload, ProgressFcn and
%   CancelRequestedFcn among them, are then ignored. If the user
%   cancelled MONITOR, ebrains.external.webprogress.upload raises an error instead of
%   sending the part.
%
%   See also ebrains.external.webprogress.download, ebrains.external.webprogress.MultipartProgressMonitor,
%   webwrite

%   Written by Eivind Hennestad

    arguments
        filePath               char         {mustBeNonempty}
        url                    char         {mustBeValidUrl}
        options.DisplayMode    char         {mustBeValidDisplay} = 'Dialog Box'
        options.UpdateInterval (1,1) double {mustBePositive}     = 1
        options.ShowFilename   (1,1) logical                     = false
        options.Filename       (1,:) char                        = ''
        options.IndentSize     (1,1) uint8                       = 0
        options.Figure         {mustBeFigureOrEmpty}             = []
        options.RequestMessage matlab.net.http.RequestMessage    = matlab.net.http.RequestMessage.empty
        options.Offset         (1,1) double {mustBeNonnegative, mustBeInteger} = 0
        options.NumBytes       (1,1) double {mustBeNonnegative, mustBeIntegerOrInf} = Inf
        options.ProgressMonitor ebrains.external.webprogress.MultipartProgressMonitor ...
                                                                 = ebrains.external.webprogress.MultipartProgressMonitor.empty
        options.ProgressFcn    {mustBeFunctionHandleOrEmpty}     = []
        options.CancelRequestedFcn {mustBeFunctionHandleOrEmpty} = []
    end

    if ~isempty(options.Filename)
        filename = options.Filename;
    elseif options.ShowFilename
        % Show the name of the local file. The URL is an upload endpoint
        % and its last segment need not match the file.
        [~, filename, ext] = fileparts(filePath);
        filename = [char(filename), char(ext)];
    else
        filename = '';
    end

    monitorOpts = {...
        'DisplayMode', options.DisplayMode, ...
        'UpdateInterval', options.UpdateInterval, ...
        'Filename', filename, ...
        'IndentSize', options.IndentSize, ...
        'Figure', options.Figure, ...
        'ProgressFcn', options.ProgressFcn, ...
        'CancelRequestedFcn', options.CancelRequestedFcn };
    
    monitor = options.ProgressMonitor;
    if isempty(monitor)
        isCancelRequested = options.CancelRequestedFcn;
        raiseIfCancelled(isCancelRequested)
        progressMonitorFcn = @(varargin) ebrains.external.webprogress.FileTransferProgressMonitor(monitorOpts{:});
    else
        if monitor.IsCancelled
            error("webprogress:upload:Cancelled", ...
                "The upload was not sent because the progress monitor was cancelled. " + ...
                "Create a new MultipartProgressMonitor to upload the file again.")
        end
        % The HTTP stack calls the function for each request, so every
        % part reports to the same monitor.
        progressMonitorFcn = @(varargin) monitor;
        isCancelRequested = [];
    end

    webOpts = matlab.net.http.HTTPOptions(...
        'ProgressMonitorFcn', progressMonitorFcn, ...
        'UseProgressMonitor', true, ...
        'ConnectTimeout', 20);

    if ~isfile(filePath)
        error("webprogress:upload:FileNotFound", ...
            "Cannot upload ""%s"" because there is no such file. Check the path.", filePath)
    end
    fileInfo = dir(filePath);
    fileSizeBytes = fileInfo.bytes;
    numBytes = min(options.NumBytes, fileSizeBytes - options.Offset);
    % An offset at the end of the file leaves nothing to send, except
    % for an empty file sent whole.
    isOffsetPastEnd = options.Offset > 0 && options.Offset >= fileSizeBytes;
    isRangePastEnd = ~isinf(options.NumBytes) && options.Offset + options.NumBytes > fileSizeBytes;
    if isOffsetPastEnd || isRangePastEnd
        error("webprogress:upload:RangeOutsideFile", ...
            "Cannot send %g bytes from byte %d of ""%s"", because the file has %d bytes. " + ...
            "Give an Offset and NumBytes that lie within the file.", ...
            options.NumBytes, options.Offset, filePath, fileSizeBytes)
    end

    % The file provider names the Content-Type after the file, which
    % suits a whole file but not a part of one.
    if options.Offset == 0 && isinf(options.NumBytes)
        provider = matlab.net.http.io.FileProvider(filePath);
    else
        provider = ebrains.external.webprogress.internal.FileRangeProvider(filePath, options.Offset, numBytes);
    end

    if isempty(options.RequestMessage)
        method = matlab.net.http.RequestMethod.PUT;
        req = matlab.net.http.RequestMessage(method, [], provider);
    else
        req = options.RequestMessage;
        req.Body = provider;
    end
    
    % The URL is already percent-encoded, as any URL handed out by a web
    % service is. Without 'literal' the URI constructor would encode it a
    % second time ("%20" would become "%2520") and the server would
    % reject every name with a space or other encoded character.
    uri = matlab.net.URI(url, 'literal');
    
    try
        [response, ~, ~] = req.send(uri, webOpts);
    catch exception
        % The progress monitor stops a cancelled transfer with an error.
        if isCancellation(exception)
            raiseCancelled()
        end
        raiseIfCancelled(isCancelRequested)
        rethrow(exception)
    end
    raiseIfCancelled(isCancelRequested)
    
    % Servers acknowledge an upload with any 2xx status, for example
    % 201 Created or 204 No Content, not only 200 OK.
    wasSuccess = response.StatusCode.getClass() == matlab.net.http.StatusClass.Successful;

    if wasSuccess && ~isempty(monitor)
        monitor.addCompletedBytes(numBytes)
    end
    
    if nargout < 1
        if ~wasSuccess
            error("webprogress:upload:RequestFailed", ...
                "Upload failed because the server responded with ""%s"". " + ...
                "Check that the URL is correct, has not expired and accepts this request method.", ...
                string(response.StatusLine))
        end
        clear wasSuccess
    end

    if nargout < 2
        clear response
    end
end

function raiseIfCancelled(isCancelRequested)
    %raiseIfCancelled - Raise an error if CancelRequestedFcn asks to stop
    if ~isempty(isCancelRequested) && isCancelRequested()
        raiseCancelled()
    end
end

function raiseCancelled()
    %raiseCancelled - Raise the error for a cancelled upload
    error("webprogress:upload:Cancelled", ...
        "The upload was cancelled.")
end

function mustBeIntegerOrInf(value)
    %mustBeIntegerOrInf - Validate that a value is a whole number or Inf
    if ~isinf(value) && value ~= round(value)
        error("webprogress:upload:InvalidNumBytes", ...
            "NumBytes must be a whole number of bytes, or Inf to send the file to its end.")
    end
end
