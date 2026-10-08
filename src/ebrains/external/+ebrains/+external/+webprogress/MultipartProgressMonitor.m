classdef (Sealed) MultipartProgressMonitor < ebrains.external.webprogress.FileTransferProgressMonitor
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
%       DisplayMode    - "Dialog Box" (default), "Command Window" or
%                        "None".
%       UpdateInterval - Minimum number of seconds between updates. The
%                        default is 1.
%       Filename       - Name shown in the progress title. The default
%                        is "".
%       IndentSize     - Number of spaces before progress printed in the
%                        Command Window. The default is 0.
%       Figure         - Figure for a uiprogressdlg. The default is [].
%       ProgressFcn    - Function called with the progress of the whole
%                        file. See ebrains.external.webprogress.FileTransferProgressMonitor.
%       CancelRequestedFcn - Function that returns true when the upload
%                        should stop. It acts as the Cancel button does.
%       CompletedBytes - Bytes of the file that the server accepted in
%                        earlier calls, as after a cancel. The default
%                        is 0. Progress counts them, and the remaining
%                        time is estimated from the parts this monitor
%                        sends.
%
%   Call close(monitor) after the last part to close the dialog or to
%   print the completion message. Deleting the monitor also closes the
%   dialog. If the user presses Cancel, or CancelRequestedFcn returns
%   true, IsCancelled becomes true and ebrains.external.webprogress.upload raises the
%   error webprogress:upload:Cancelled for the part in progress and for
%   each later part, which it does not send. To continue after a cancel,
%   create a new monitor with CompletedBytes set to the bytes the server
%   accepted, and send the remaining parts.
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

    properties (Dependent)
        CompletedBytes  % Bytes of the parts that were sent successfully
        IsCancelled     % Whether the transfer was cancelled, by the Cancel button or CancelRequestedFcn
    end

    properties (Access = private)
        IsClosing = false     % Whether done should close the display
        PartBytes = 0         % Bytes sent of the part in progress
        CompletedPartBytes = 0 % Bytes of the parts that were sent successfully
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
                options.ProgressFcn             {mustBeFunctionHandleOrEmpty} = []
                options.CancelRequestedFcn      {mustBeFunctionHandleOrEmpty} = []
                options.CompletedBytes (1,1) double {mustBeNonnegative}   = 0
            end
            completedBytes = options.CompletedBytes;
            if completedBytes > totalBytes
                error("webprogress:progressMonitor:CompletedBytesAboveTotal", ...
                    "CompletedBytes is %d, more than the %d bytes of the file. Give the " + ...
                    "bytes the server has accepted so far.", completedBytes, totalBytes)
            end
            % The bytes accepted before this monitor go to the parent as
            % StartBytes, which its remaining-time estimate leaves out.
            options = rmfield(options, 'CompletedBytes');
            nameValues = namedargs2cell(options);
            obj@ebrains.external.webprogress.FileTransferProgressMonitor(nameValues{:}, ...
                FileSizeBytes=totalBytes, StartBytes=completedBytes);
            obj.CompletedPartBytes = completedBytes;
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
            obj.PartBytes = 0;
            obj.IsClosing = true;
            obj.done()
        end

        function completedBytes = get.CompletedBytes(obj)
            completedBytes = obj.CompletedPartBytes;
        end

        function tf = get.IsCancelled(obj)
        %get.IsCancelled - Return whether the transfer was cancelled
        %   CancelRequestedFcn is asked as well, so that a cancel
        %   requested between two parts stops the next part before it
        %   is sent, not at its first progress report.
            tf = obj.WasCancelled || isCancelRequested(obj.CancelRequestedFcn);
        end
    end

    methods (Hidden)
        function addCompletedBytes(obj, numBytes)
        %addCompletedBytes - Count a part that was sent successfully
        %   ebrains.external.webprogress.upload calls this when the server accepts a part.
        %   It is hidden because it is not meant to be called by users.
            arguments
                obj
                numBytes (1,1) double {mustBeNonnegative}
            end
            obj.CompletedPartBytes = obj.CompletedPartBytes + numBytes;
            obj.PartBytes = 0;
            % The throttle may have held back the last bytes of the part,
            % and done does not report them because it keeps the display
            % open between parts.
            obj.reportProgress()
        end
    end

    methods (Access = protected)
        function update(obj, varargin)
        %update - Show the progress of a part as its request is sent
        %   The response to a part does not carry the file, so the bytes
        %   of its body are not progress. A Cancel pressed while the
        %   response arrives still has to be noticed, because the
        %   progress dialog only reports it when the monitor asks.
            if isequal(obj.Direction, matlab.net.http.MessageType.Response)
                if obj.WasCancelled || obj.cancelWasRequested()
                    obj.stopTransfer()
                end
                return
            end
            if ~isempty(obj.Value)
                obj.PartBytes = double(obj.Value);
            end
            update@ebrains.external.webprogress.FileTransferProgressMonitor(obj, varargin{:})
        end

        function transferredBytes = getTransferredBytes(obj)
        %getTransferredBytes - Return the completed parts and the part in progress
            transferredBytes = obj.CompletedPartBytes + obj.PartBytes;
        end

        function fileSizeBytes = getFileSizeBytes(obj)
        %getFileSizeBytes - Return the size of the whole file
        %   The size of each request covers one part only.
            fileSizeBytes = obj.FileSizeBytes;
        end
    end
end
