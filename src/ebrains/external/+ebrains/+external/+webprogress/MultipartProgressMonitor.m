classdef MultipartProgressMonitor < ebrains.external.webprogress.FileTransferProgressMonitor
%MultipartProgressMonitor - One progress display for a file sent in several parts
%   monitor = ebrains.external.webprogress.MultipartProgressMonitor(TOTALBYTES) creates a
%   progress monitor for a file of TOTALBYTES bytes that is uploaded in
%   several requests, one part per request. Pass it to each upload with
%   ebrains.external.webprogress.upload(...,ProgressMonitor=monitor). The display stays
%   open between the requests and shows the progress of the whole file.
%   An upload that succeeds adds its part to CompletedBytes, so a part
%   that fails and is sent again is counted once.
%
%   monitor = ebrains.external.webprogress.MultipartProgressMonitor(TOTALBYTES,Name=Value)
%   sets display options:
%       DisplayMode    - "Dialog Box" (default) or "Command Window".
%       UpdateInterval - Minimum number of seconds between updates. The
%                        default is 1.
%       Filename       - Name shown in the progress title. The default
%                        is "".
%       IndentSize     - Number of spaces before progress printed in the
%                        Command Window. The default is 0.
%       Figure         - Figure for a uiprogressdlg. The default is [].
%
%   Call close(monitor) after the last part to close the dialog or to
%   print the completion message. Deleting the monitor also closes the
%   dialog. If the user presses Cancel, the current request is aborted
%   and IsCancelled becomes true, and ebrains.external.webprogress.upload raises an error
%   for each later part.
%
%   Example: Upload a file in parts of 100 MB
%       fileInfo = dir(filePath);
%       partSize = 100 * 2^20;
%       monitor = ebrains.external.webprogress.MultipartProgressMonitor(fileInfo.bytes, ...
%           "DisplayMode", "Command Window");
%       for offset = 0:partSize:fileInfo.bytes-1
%           numBytes = min(partSize, fileInfo.bytes - offset);
%           partUrl = getPartUrl(offset); % URL from the storage service
%           ebrains.external.webprogress.upload(filePath, partUrl, "Offset", offset, ...
%               "NumBytes", numBytes, "ProgressMonitor", monitor);
%       end
%       close(monitor)
%
%   See also ebrains.external.webprogress.upload, ebrains.external.webprogress.FileTransferProgressMonitor

%   Written by Eivind Hennestad

    properties (SetAccess = immutable)
        TotalBytes (1,1) double % Size of the whole file in bytes
    end

    properties (Dependent)
        CompletedBytes  % Bytes of the parts that were sent successfully
        IsCancelled     % Whether the user cancelled the transfer
    end

    properties (Access = private)
        IsClosing = false     % Whether done should close the display
        IsPartCounted = false % Whether Value is already included in CompletedBytes
    end

    methods
        function obj = MultipartProgressMonitor(totalBytes, options)
            arguments
                totalBytes             (1,1) double {mustBeNonnegative}
                options.DisplayMode    (1,1) string {mustBeValidDisplay}  = "Dialog Box"
                options.UpdateInterval (1,1) double {mustBeNonnegative}   = 1
                options.Filename       (1,1) string                       = ""
                options.IndentSize     (1,1) uint8                        = 0
                options.Figure                      {mustBeFigureOrEmpty} = []
            end
            nameValues = namedargs2cell(options);
            obj@ebrains.external.webprogress.FileTransferProgressMonitor(nameValues{:}, ...
                'FileSizeBytes', totalBytes);
            obj.TotalBytes = totalBytes;
        end

        function done(obj)
        %done - Keep the display open when one request finishes
        %   The HTTP stack calls done after each request. The display
        %   closes only through close.
            if obj.IsClosing
                done@ebrains.external.webprogress.FileTransferProgressMonitor(obj)
            end
        end

        function close(obj)
        %close - Close the dialog or print the completion message
        %   The completion message counts the parts that were sent
        %   successfully, and leaves out a last part that failed.
            obj.IsPartCounted = true;
            obj.IsClosing = true;
            obj.done()
        end

        function addCompletedBytes(obj, numBytes)
        %addCompletedBytes - Count a part that was sent successfully
        %   ebrains.external.webprogress.upload calls this when the server accepts a part.
            arguments
                obj
                numBytes (1,1) double {mustBeNonnegative}
            end
            obj.StartBytes = obj.StartBytes + numBytes;
            obj.IsPartCounted = true;
        end

        function completedBytes = get.CompletedBytes(obj)
            completedBytes = obj.StartBytes;
        end

        function tf = get.IsCancelled(obj)
            tf = obj.WasCancelled;
        end
    end

    methods (Access = protected)
        function update(obj, varargin)
        %update - Show the progress of a part as its request is sent
        %   The response to a part does not carry the file, so the bytes
        %   of its body are not progress. Value counts the bytes of the
        %   next part once its request reports them.
            if isequal(obj.Direction, matlab.net.http.MessageType.Response)
                return
            end
            obj.IsPartCounted = false;
            update@ebrains.external.webprogress.FileTransferProgressMonitor(obj, varargin{:})
        end

        function transferredBytes = getTransferredBytes(obj)
        %getTransferredBytes - Return the completed parts and the part in progress
        %   Value keeps the size of a part after addCompletedBytes has
        %   counted it, until the next request reports its first bytes.
            transferredBytes = obj.StartBytes;
            if ~obj.IsPartCounted
                transferredBytes = transferredBytes + double(obj.Value);
            end
        end

        function fileSizeBytes = getFileSizeBytes(obj)
        %getFileSizeBytes - Return the size of the whole file
        %   The size of each request covers one part only.
            fileSizeBytes = obj.TotalBytes;
        end
    end
end
