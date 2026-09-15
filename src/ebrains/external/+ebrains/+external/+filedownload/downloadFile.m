function strLocalFilename = downloadFile(strLocalFilename, strURLFilename, options)
%downloadFile Download and save a file from web while displaying progress.
%
%   downloadFile(strLocalFilename, strURLFilename) downloads the file
%   specified by the url strURLFilename to the local path specified by
%   strLocalFile
%
%   strLocalFilename = downloadFile(localFilename, strURLFilename)
%   downloads the file and returns the absolute path of the downloaded file
%
%   Options:
%       DisplayMode     : Where to display progress. Options: 'Dialog Box' (default) or 'Command Window'
%       UpdateInterval  : Interval (in seconds) for updating progress. Default = 1 second.
%       ShowFilename    : Whether to show name of downloaded file. Default = false.
%       Filename        : Name to show in the progress display. Default = '' (the name is
%                         taken from the URL when ShowFilename is true).
%       IndentSize      : Size of indentation if displaying progress in command window.
%       Figure          : Parent figure for uiprogressdlg. Default = [].
%       FileSizeBytes   : Known file size when HTTP progress size is unavailable. Default = NaN.

%   Written by Eivind Hennestad
%
%   Bundled copy of filedownload v1.2.0 (web-transfer-progress-monitor).
%   Differs from the release by the namespace import below, by treating
%   the URL as already encoded when the URI is built, by the Filename
%   option for the progress display, and by raising
%   filedownload:downloadFailed on a response status outside 2xx: send
%   returns normally on an HTTP error, and the file consumer writes the
%   error body to the file as if it were the content.

    arguments
        strLocalFilename       char         {mustBeNonempty}
        strURLFilename         char         {mustBeValidUrl}
        options.DisplayMode    char         {mustBeValidDisplay} = 'Dialog Box'
        options.UpdateInterval (1,1) double {mustBePositive}     = 1
        options.ShowFilename   (1,1) logical                     = false
        options.Filename       char                              = ''
        options.IndentSize     (1,1) uint8                       = 0
        options.Figure         {mustBeFigureOrEmpty}             = []
        options.FileSizeBytes  (1,1) double                      = nan
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
        'Figure', options.Figure, ...
        'FileSizeBytes', options.FileSizeBytes };
    
    webOpts = matlab.net.http.HTTPOptions(...
        'ProgressMonitorFcn', @(opts) FileTransferProgressMonitor(monitorOpts{:}),...
        'UseProgressMonitor', true, ...
        'ConnectTimeout', 20);

    % Create a file consumer for saving the file
    consumer = matlab.net.http.io.FileConsumer(strLocalFilename);
    
    method = matlab.net.http.RequestMethod.GET;
    req = matlab.net.http.RequestMessage(method, [], []);
    
    % The URL is already percent-encoded, as any URL handed out by a web
    % service is. Without 'literal' the URI constructor would encode it a
    % second time ("%20" would become "%2520") and the server would answer
    % 404 for every name with a space or other encoded character.
    strURLFilename = matlab.net.URI(strURLFilename, 'literal');
    
    [resp, ~, ~] = req.send(strURLFilename, webOpts, consumer);

    % send returns normally on an HTTP error status, and the file consumer
    % has then written the error body to the file, so the status is checked
    % here for the caller to learn that the file does not hold the content.
    statusCode = int32(resp.StatusCode);
    if statusCode < 200 || statusCode >= 300
        error('filedownload:downloadFailed', ...
            'Download failed: %s', char(string(resp.StatusLine)))
    end

    strLocalFilename = resp.Body.Data;

    if nargout < 1
        clear strLocalFilename
    end
end
