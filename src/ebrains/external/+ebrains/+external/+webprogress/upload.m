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
%   See also ebrains.external.webprogress.download, webwrite

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
        'Figure', options.Figure };
    
    webOpts = matlab.net.http.HTTPOptions(...
        'ProgressMonitorFcn', @(opts) ebrains.external.webprogress.FileTransferProgressMonitor(monitorOpts{:}),...
        'UseProgressMonitor', true, ...
        'ConnectTimeout', 20);

    % Create a file provider for uploading the file
    provider = matlab.net.http.io.FileProvider(filePath);

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
    
    [response, ~, ~] = req.send(uri, webOpts);
    
    % Servers acknowledge an upload with any 2xx status, for example
    % 201 Created or 204 No Content, not only 200 OK.
    wasSuccess = response.StatusCode.getClass() == matlab.net.http.StatusClass.Successful;
    
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
