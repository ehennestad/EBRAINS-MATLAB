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
%       IndentSize      : Size of indentation if displaying progress in command window.
%       Figure          : Parent figure for uiprogressdlg. Default = [].
%       FileSizeBytes   : Known file size when HTTP progress size is unavailable. Default = NaN.

%   Written by Eivind Hennestad
%
%   Bundled copy of filedownload v1.2.0 (web-transfer-progress-monitor).
%   Differs from the release by the namespace import below and by
%   treating the URL as already encoded when the URI is built.

    arguments
        strLocalFilename       char         {mustBeNonempty}
        strURLFilename         char         {mustBeValidUrl}
        options.DisplayMode    char         {mustBeValidDisplay} = 'Dialog Box'
        options.UpdateInterval (1,1) double {mustBePositive}     = 1
        options.ShowFilename   (1,1) logical                     = false
        options.IndentSize     (1,1) uint8                       = 0
        options.Figure         {mustBeFigureOrEmpty}             = []
        options.FileSizeBytes  (1,1) double                      = nan
    end

    import ebrains.external.filedownload.*

    if options.ShowFilename
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

    strLocalFilename = resp.Body.Data;

    if nargout < 1
        clear strLocalFilename
    end
end
