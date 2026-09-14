function [wasSuccess, response] = uploadFile(strLocalFilename, strURLFilename, options)
%uploadFile Upload a file to web while displaying progress.
%
%   uploadFile(strLocalFilename, strURLFilename) uploads the file
%   specified by the local path `strLocalFilename` to the web location
%   specified by `strURLFilename`.
%
%   wasSuccess = uploadFile(localFilename, strURLFilename) uploads the file
%   and returns a boolean value indicating if the upload was successful or
%   not.
%
%   [wasSuccess, response] = uploadFile(localFilename, strURLFilename)
%   uploads the file and returns the wasSuccess boolean and a response
%   object.
%
%   Options:
%       DisplayMode     : Where to display progress. Options: 'Dialog Box' (default) or 'Command Window'
%       UpdateInterval  : Interval (in seconds) for updating progress. Default = 1 second.
%       ShowFilename    : Whether to show name of uploaded file. Default = false.
%       Filename        : Name to show in the progress display. Default = '' (the name is
%                         taken from the URL when ShowFilename is true).
%       IndentSize      : Size of indentation if displaying progress in command window.
%       Figure          : Parent figure for uiprogressdlg. Default = [].
%       RequestMessage  : Custom request message. Its body is replaced with the local file provider.

%   Written by Eivind Hennestad
%
%   Bundled copy of filedownload v1.2.0 (web-transfer-progress-monitor).
%   Differs from the release by the namespace import below, by treating
%   the URL as already encoded when the URI is built, by an empty
%   request message as the default of RequestMessage (the release's []
%   cannot be converted to that class, so every call failed at
%   validation), by the Filename option for the progress display, and by
%   counting any 2xx status as success where the release accepts only 200.

    arguments
        strLocalFilename       char         {mustBeNonempty}
        strURLFilename         char         {mustBeValidUrl}
        options.DisplayMode    char         {mustBeValidDisplay} = 'Dialog Box'
        options.UpdateInterval (1,1) double {mustBePositive}     = 1
        options.ShowFilename   (1,1) logical                     = false
        options.Filename       char                              = ''
        options.IndentSize     (1,1) uint8                       = 0
        options.Figure         {mustBeFigureOrEmpty}             = []
        options.RequestMessage matlab.net.http.RequestMessage    = matlab.net.http.RequestMessage.empty
    end

    import ebrains.external.filedownload.*

    if ~isempty(options.Filename)
        filename = options.Filename;
    elseif options.ShowFilename
        [~, filename, ext] = fileparts(strURLFilename);
        filename = [char(filename), char(ext)];
    else
        filename = '';
    end

    monitorOpts = {...
        'DisplayMode', options.DisplayMode, ...
        'UpdateInterval', options.UpdateInterval, ...
        'Filename', filename, ...
        'IndentSize', options.IndentSize, ...
        'Figure', options.Figure };
    
    webOpts = matlab.net.http.HTTPOptions(...
        'ProgressMonitorFcn', @(opts) FileTransferProgressMonitor(monitorOpts{:}),...
        'UseProgressMonitor', true, ...
        'ConnectTimeout', 20);

    % Create a file provider for uploading the file
    provider = matlab.net.http.io.FileProvider(strLocalFilename);

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
    strURLFilename = matlab.net.URI(strURLFilename, 'literal');
    
    [response, ~, ~] = req.send(strURLFilename, webOpts);
    
    % A stored object may be answered with 201 Created rather than 200 OK,
    % so any 2xx status counts as success.
    statusCode = int32(response.StatusCode);
    wasSuccess = statusCode >= 200 && statusCode < 300;
    
    if nargout < 1
        if ~wasSuccess
            error(string(response.StatusLine))
        end
        clear wasSuccess
    end

    if nargout < 2
        clear response
    end
end
