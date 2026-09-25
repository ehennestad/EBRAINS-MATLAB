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
%   ebrains.external.webprogress.download raises an error if the server responds with a
%   status that is not a successful 2xx status, if the connection closes
%   before the number of bytes the server announced in its
%   Content-Length header has arrived, or if the server announces
%   different lengths in several Content-Length headers. In each case no
%   file is saved.
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
    end

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
        'FileSizeBytes', options.FileSizeBytes };
    
    webOpts = matlab.net.http.HTTPOptions(...
        'ProgressMonitorFcn', @(opts) ebrains.external.webprogress.FileTransferProgressMonitor(monitorOpts{:}),...
        'UseProgressMonitor', true, ...
        'ConnectTimeout', 20);

    isFolderTarget = isfolder(targetPath);
    if isFolderTarget
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

    % Receive the file in a temporary file that replaces the target only
    % after a successful download, so an existing file survives a failed or
    % interrupted download. The file consumer writes the response body
    % whatever the status, and it overwrites its target as soon as data
    % arrives. The temporary file sits in the target folder so that the
    % final move is a rename, not a copy. Its .part extension stops the file
    % consumer from adding an extension of its own, such as ".txt" for a
    % text/plain response. onCleanup deletes the temporary file when the
    % function exits early, including by an error or Ctrl+C.
    [~, folderInfo] = fileattrib(targetFolder);
    targetFolder = folderInfo.Name; % Full path, also for a relative input
    temporaryFile = [tempname(targetFolder), '.part'];
    temporaryFileCleanup = onCleanup(@() deleteIfFile(temporaryFile));
    consumer = matlab.net.http.io.FileConsumer(temporaryFile);
    
    method = matlab.net.http.RequestMethod.GET;
    req = matlab.net.http.RequestMessage(method, [], []);
    
    [resp, ~, ~] = req.send(uri, webOpts, consumer);

    if resp.StatusCode.getClass() ~= matlab.net.http.StatusClass.Successful
        error("webprogress:download:RequestFailed", ...
            "Download failed because the server responded with ""%s"". " + ...
            "Check that the URL is correct and has not expired.", ...
            string(resp.StatusLine))
    end

    assertCompleteTransfer(resp, temporaryFile)

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

    % The file consumer creates its file when the first data arrives, so a
    % response with an empty body leaves no file to move.
    if ~isfile(temporaryFile)
        fclose(fopen(temporaryFile, 'w'));
    end

    targetFile = string(fullfile(targetFolder, targetName));
    [isMoved, moveMessage] = movefile(temporaryFile, targetFile, 'f');
    if ~isMoved
        error("webprogress:download:CannotSaveFile", ...
            "Cannot save the downloaded file as ""%s"": %s", targetFile, moveMessage)
    end

    savedFilePath = targetFile;

    if nargout < 1
        clear savedFilePath
    end
end

function assertCompleteTransfer(response, filePath)
    %assertCompleteTransfer - Raise an error if the body is shorter than announced
    %   The HTTP client ends a transfer without an error when the server
    %   closes the connection early, so a dropped connection would save a
    %   truncated file. The size of the received file is compared with the
    %   Content-Length of the response. Without that header, as for a
    %   chunked response, there is nothing to compare with. A body with a
    %   Content-Encoding such as gzip is decoded while it is saved, so its
    %   saved size differs from Content-Length and is not compared. The
    %   coding "identity" means a body that was not transformed, so its
    %   sizes do match. RFC 9110 reserves that token for Accept-Encoding
    %   and RFC 2616 defined it as a content coding, which is why a server
    %   may still send it in Content-Encoding.
    %
    %   A response with several Content-Length headers of different values
    %   is invalid (RFC 9110, section 8.6), and the length of its body
    %   cannot be known, so it is an error. Repeated headers with the same
    %   value count as one.
    lengthFields = response.getFields("Content-Length");
    if isempty(lengthFields)
        return
    end
    declaredBytes = unique(lengthFields.convert());
    if ~isscalar(declaredBytes)
        error("webprogress:download:InvalidContentLength", ...
            "The server gave %d different lengths for the file (%s bytes), so the " + ...
            "download cannot be checked and the file was not saved. Try the download again.", ...
            numel(declaredBytes), strjoin(string(declaredBytes), ", "))
    end

    encodingField = response.getFields("Content-Encoding");
    if ~isempty(encodingField) && ~strcmpi(strtrim(string(encodingField(end).Value)), "identity")
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
