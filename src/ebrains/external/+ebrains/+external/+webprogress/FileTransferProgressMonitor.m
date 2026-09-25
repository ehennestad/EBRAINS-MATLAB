classdef FileTransferProgressMonitor < matlab.net.http.ProgressMonitor
%FileTransferProgressMonitor - Progress monitor for HTTP file transfers
%
%   Create a function handle to provide to matlab.net.http.HTTPOptions:
%       progressMonitorFcn = @ebrains.external.webprogress.FileTransferProgressMonitor;
%
%   Create a function handle to provide to matlab.net.http.HTTPOptions
%   while specifying custom options for the monitor:
%       monitorOptions = {'DisplayMode', 'Command Window'};
%       progressMonitorFcn = @(varargin) ebrains.external.webprogress.FileTransferProgressMonitor(monitorOptions{:})
%
%   Supported options:
%       DisplayMode     : Where to display progress. Options: 'Dialog Box' (default) or 'Command Window'
%       UpdateInterval  : Interval (in seconds) for updating progress. Default = 1 second.
%       Filename        : Name of transferred file. If provided, filename is displayed during download/upload.
%       IndentSize      : Size of indentation if displaying progress in command window. Default = 0.
%       Figure          : Parent figure for uiprogressdlg. Default = [].
%       FileSizeBytes   : Known file size when ProgressMonitor.Max is unavailable. Default = NaN.

%   Inspired by example in matlab.net.http.ProgressMonitor
%
%   Written by Eivind Hennestad
    
    properties (SetAccess = private) % User settings for monitor
        DisplayMode = "Dialog Box"  % Where to display progress.
        UpdateInterval = 1          % Interval (in seconds) for updating progress.
        Filename = ""               % Name of downloaded/uploaded file.
        IndentSize = 0              % Size of indentation (number of spaces) if displaying progress in command window.
        Figure = []                 % Parent figure for uiprogressdlg.
        FileSizeBytes = nan         % Known file size when ProgressMonitor.Max is not available.
    end

    properties % Implement superclass properties (matlab.net.http.ProgressMonitor)
        Direction matlab.net.http.MessageType % Direction of the current message
        Value uint64                % Number of transferred bytes
    end

    properties (Dependent)
        ActionName                  % Name of current action, "Download" or "Upload"
        FileSizeMb                  % Full size of file being transferred in megabytes
        TransferredMb               % Size of currently transferred data in megabytes
        PercentTransferred          % Percent of file downloaded/uploaded
        UseWaitbarDialog            % Whether to display progress in a waitbar dialog
        UseUIProgressDialog         % Whether to display progress in a uiprogressdlg.
        UseCommandWindow            % Whether to display progress in the command window
    end

    properties (Access = protected)
        StartTime                   % Time when transfer started
        LastUpdateTime              % Time when progress was last updated
        HasTransferStarted = false  % Whether download or upload has started
        WaitbarHandle               % Handle to waitbar dialog
        ProgressDialogHandle        % Handle to uiprogressdlg.
        PreviousMessage = ''        % Previous message displayed in command window
        BodyDirection               % Direction of the message that carries the file
        BodySizeBytes               % Size in bytes of the message that carries the file
        HasDisplayedProgress = false % Whether progress has been displayed at least once
        WasCancelled = false        % Whether the user cancelled the transfer
    end

    properties (Constant, Access = private)
        % Longest delay the monitor accepts before the HTTP stack makes
        % its first call to it. Measured against a local server, a
        % transfer of a few kilobytes reports no progress at all when
        % this is above 0.01 seconds.
        MaximumCallbackInterval = 0.01
    end
    
    methods
        function obj = FileTransferProgressMonitor(options)
            arguments
                options.DisplayMode    (1,1) string {mustBeValidDisplay}  = "Dialog Box"
                options.UpdateInterval (1,1) double {mustBeNonnegative}   = 1
                options.Filename       (1,1) string                       = ""
                options.IndentSize     (1,1) uint8                        = 0
                options.Figure                      {mustBeFigureOrEmpty} = []
                options.FileSizeBytes  (1,1) double                       = nan
            end

            for optionName = string(fieldnames(options))'
                obj.(optionName) = options.(optionName);
            end
            
            % Interval is the delay before the HTTP stack makes its
            % first call to the monitor, not a limit on how often it
            % calls, and the stack skips that call when the transfer
            % finishes first. Leaving it at UpdateInterval therefore
            % hides every transfer that completes within one interval.
            % Cap it well below the shortest transfer worth reporting;
            % UpdateInterval still limits how often the display is
            % refreshed once progress starts arriving.
            obj.Interval = min(obj.UpdateInterval, obj.MaximumCallbackInterval);
            [obj.StartTime, obj.LastUpdateTime] = deal( tic );
        end
        
        function done(obj)
            if ~isempty(obj.ProgressDialogHandle)
                obj.closeProgressDialog();
            elseif ~isempty(obj.WaitbarHandle)
                obj.closeWaitbar();
            elseif ~isempty(obj.PreviousMessage) && obj.UseCommandWindow
                msgStr = obj.getTransferCompletedMessage();
                obj.updateCommandWindowMessage(msgStr)
            end
        end
        
        function delete(obj)
        %delete - Close any open progress dialog or waitbar
            obj.closeProgressDialog();
            obj.closeWaitbar();
        end
        
        function set.Value(obj, value)
        %set.Value - Set the transferred byte count and update progress
            obj.Value = value;
            obj.update();
        end

        function name = get.ActionName(obj)
        %get.ActionName - Return "Upload" or "Download"
            direction = obj.BodyDirection;
            if isempty(direction)
                direction = obj.Direction;
            end

            if direction == matlab.net.http.MessageType.Request
                name = "Upload";
            elseif direction == matlab.net.http.MessageType.Response
                name = "Download";
            else
                error("webprogress:progressMonitor:UnknownDirection", ...
                    "Cannot name the transfer because its direction is neither a " + ...
                    "request nor a response. Set Direction before reading ActionName.")
            end
        end

        function fileSizeMb = get.FileSizeMb(obj)
        %get.FileSizeMb - Return the file size in megabytes
            fileSizeMb = obj.getFileSizeMb();
        end

        function transferredMb = get.TransferredMb(obj)
        %get.TransferredMb - Return the transferred size in megabytes
            transferredMb = obj.getTransferredMb();
        end

        function percentTransferred = get.PercentTransferred(obj)
        %get.PercentTransferred - Return the percentage transferred
            percentTransferred = obj.computePercentTransferred();
        end

        function tf = get.UseWaitbarDialog(obj)
        %get.UseWaitbarDialog - Return whether progress uses a waitbar
            tf = strcmpi(obj.DisplayMode, 'Dialog Box') ...
                && ~ebrains.external.webprogress.FileTransferProgressMonitor.isWebBasedUIFigure(obj.Figure);
        end

        function tf = get.UseUIProgressDialog(obj)
        %get.UseUIProgressDialog - Return whether progress uses uiprogressdlg
            tf = strcmpi(obj.DisplayMode, 'Dialog Box') ...
                && ebrains.external.webprogress.FileTransferProgressMonitor.isWebBasedUIFigure(obj.Figure);
        end

        function tf = get.UseCommandWindow(obj)
        %get.UseCommandWindow - Return whether progress is printed
            tf = strcmpi(obj.DisplayMode, 'Command Window');
        end
    end
    
    methods (Access = protected)

        function update(obj, ~)
        %update - Refresh the progress display after Value changes

            % The HTTP stack keeps reporting byte counts for a while
            % after a cancellation, because it aborts the transfer at
            % its next opportunity rather than at once. Without this the
            % next report would open a fresh dialog for a transfer the
            % user has already given up on.
            if obj.WasCancelled
                return
            end

            % A message without a body reports Max as 0. After an upload,
            % the server's empty response switches Direction to Response
            % while Value keeps the uploaded byte count. Remember the
            % message that carries the file so that progress and the
            % completion message keep describing that transfer.
            if ~isempty(obj.Max) && obj.Max > 0
                obj.BodyDirection = obj.Direction;
                obj.BodySizeBytes = obj.Max;
            end

            % Display the first progress as soon as it arrives.
            % UpdateInterval limits how often the display is refreshed
            % after that, so waiting for it here would leave a transfer
            % that finishes within one interval showing nothing at all.
            doUpdate = ~obj.HasDisplayedProgress ...
                || toc(obj.LastUpdateTime) > obj.UpdateInterval;

            if ~isempty(obj.Value) && doUpdate
                
                if isempty(obj.Max) && isnan(obj.FileSizeBytes)
                    % Maximum (size of request/response) is not known,
                    % file transfer did not start yet.
                    %
                    % A message without a body reports Max as 0, not as
                    % empty, so it does not match here and would fall
                    % through to the size message below and format an
                    % unknown size as "NaN MB". No transfer reaches that
                    % state. Logging what the stack sets shows it leaves
                    % Value unset for a message without a body, and
                    % update only ever runs from set.Value. The one
                    % message with Max 0 that does carry a Value is the
                    % empty response after an upload, and by then
                    % BodySizeBytes already holds the uploaded size. Add
                    % a Max == 0 case here only alongside a transfer that
                    % is shown to reach it.
                    progressValue = 0;
                    msg = sprintf('Waiting for %s to start...', lower(obj.ActionName));
                else
                    % Maximum known, update proportional value. Keep it
                    % within 0 to 1, which uiprogressdlg requires. The
                    % fraction exceeds 1 when a caller-supplied
                    % FileSizeBytes is smaller than the transfer. max
                    % ignores NaN, so an unknown size gives 0 rather
                    % than an error.
                    progressValue = min(max(obj.PercentTransferred / 100, 0), 1);

                    % An upload and a download are described the same
                    % way. ActionName rejects any other direction.
                    msg = obj.getProgressMessage();
                    obj.HasTransferStarted = true;
                end

                if obj.cancelWasRequested()
                    obj.cancelTransfer();
                    return
                end

                if isempty(obj.ProgressDialogHandle) && obj.UseUIProgressDialog
                    obj.ProgressDialogHandle = uiprogressdlg(obj.Figure, ...
                        'Title', obj.getProgressTitle(), ...
                        'Message', msg, ...
                        'Value', progressValue, ...
                        'Cancelable', 'on');
                elseif isempty(obj.WaitbarHandle) && obj.UseWaitbarDialog
                    % If we don't have a progress bar, display it for first time
                    obj.WaitbarHandle = waitbar(progressValue, msg, ...
                        'Name', obj.getProgressTitle(), ...
                        'CreateCancelBtn', @(~,~) obj.cancelTransfer());
                elseif isempty(obj.PreviousMessage) && obj.UseCommandWindow
                    indentStr = repmat(' ', 1, obj.IndentSize);
                    fprintf('%s%s', indentStr, obj.getProgressTitle() )
                    obj.updateCommandWindowMessage(msg)
                end

                % Creating the waitbar draws it, so its cancel button can
                % fire before its handle reaches WaitbarHandle and the
                % close in cancelTransfer finds nothing to close.
                if obj.WasCancelled
                    obj.closeWaitbar();
                    return
                end

                if obj.HasTransferStarted
                    if obj.UseUIProgressDialog
                        obj.updateProgressDialog(progressValue, msg);
                    elseif obj.UseWaitbarDialog
                        obj.updateWaitbar(progressValue, msg);
                    else
                        obj.updateCommandWindowMessage(msg)
                    end
                end

                obj.HasDisplayedProgress = true;
                obj.LastUpdateTime = tic;
            end
        end
        
        function updateCommandWindowMessage(obj, msgStr)
        %updateCommandWindowMessage - Replace the last printed progress message

            % A progress message arrives split into parts once a time
            % estimate is included; join them before formatting.
            if iscell(msgStr)
                msgStr = strjoin(msgStr, ' ');
            end

            % Add indentation
            msgStr = sprintf('%s%s', repmat(' ', 1, obj.IndentSize), msgStr);

            if ~isempty(obj.PreviousMessage)
                % char(8) = backspace
                deletePrevStr = char(8*ones(1, length(obj.PreviousMessage)+1));
            else
                deletePrevStr = '';
            end
            % Print on new line to prevent messy output in case users enter
            % input on the command window.
            fprintf('%s\n%s', deletePrevStr, msgStr);
            obj.PreviousMessage = msgStr;
        end
    end
    
    methods (Access = protected)
        function updateProgressDialog(obj, progressValue, msg)
        %updateProgressDialog - Update the value and message of uiprogressdlg
            if obj.cancelWasRequested()
                obj.cancelTransfer();
                return
            end

            if ~obj.progressDialogIsValid()
                obj.ProgressDialogHandle = [];
                return
            end

            obj.ProgressDialogHandle.Value = progressValue;
            obj.ProgressDialogHandle.Message = msg;
            obj.ProgressDialogHandle.Title = obj.getProgressTitle();

            % UI figures update through MATLAB's event queue during the blocking transfer.
            drawnow limitrate
        end

        function updateWaitbar(obj, progressValue, msg)
        %updateWaitbar - Update the value and message of the waitbar
            if ~obj.waitbarIsValid()
                obj.WaitbarHandle = [];
                return
            end

            waitbar(progressValue, obj.WaitbarHandle, msg);
        end

        function cancelTransfer(obj)
        %cancelTransfer - Abort the transfer and close the progress display
        %   Called when the user presses Cancel or closes the progress
        %   window. WasCancelled keeps update from opening a new display
        %   for the byte counts that still arrive before the HTTP stack
        %   acts on the abort.
            obj.WasCancelled = true;

            % CancelFcn is empty until the HTTP stack assigns it, which
            % it does only for a transfer that the stack itself drives.
            if ~isempty(obj.CancelFcn)
                obj.CancelFcn();
            end

            obj.closeProgressDialog();
            obj.closeWaitbar();
        end

        function tf = cancelWasRequested(obj)
        %cancelWasRequested - Return whether the user pressed Cancel
            tf = obj.progressDialogIsValid() ...
                && obj.ProgressDialogHandle.CancelRequested;
        end

        function tf = progressDialogIsValid(obj)
        %progressDialogIsValid - Return whether the progress dialog is open
            tf = ~isempty(obj.ProgressDialogHandle) ...
                && isvalid(obj.ProgressDialogHandle);
        end

        function tf = waitbarIsValid(obj)
        %waitbarIsValid - Return whether the waitbar is open
            tf = ~isempty(obj.WaitbarHandle) ...
                && isvalid(obj.WaitbarHandle);
        end

        function closeProgressDialog(obj)
        %closeProgressDialog - Close the progress dialog if it is open
            if ~isempty(obj.ProgressDialogHandle)
                if obj.progressDialogIsValid()
                    close(obj.ProgressDialogHandle);
                end
                obj.ProgressDialogHandle = [];
            end
        end

        function closeWaitbar(obj)
        %closeWaitbar - Delete the waitbar if it is open

            % Close the progress waitbar by deleting the handle so
            % CloseRequestFcn isn't called, because waitbar calls
            % cancelAndClose(), which would cause recursion.
            if ~isempty(obj.WaitbarHandle)
                delete(obj.WaitbarHandle);
                obj.WaitbarHandle = [];
            end
        end
    end

    methods (Access = protected) % Format messages for display

        function titleStr = getProgressTitle(obj)
        %getProgressTitle - Return a title such as "Downloading data.json"

            % Make ongoing present action verb, i.e [Download]ing or [Upload]ing
            action = sprintf('%sing', obj.ActionName);

            if strlength(obj.Filename) > 0
                if strlength(obj.Filename) <= 26
                    displayedFilename = obj.Filename;
                else
                    displayedFilename = obj.shortenFilename(obj.Filename);
                end
                titleStr = sprintf('%s %s', action, displayedFilename);
            else
                titleStr = sprintf('%s File...', action);
            end
        end
        
        function strMessage = getProgressMessage(obj)
        %getProgressMessage - Return the progress and time estimate message
            
            % getRemainingTimeEstimate always returns a message, either
            % an estimate or a note that it cannot make one yet.
            strMessage = strjoin({obj.getTransferStatus(), ...
                obj.getRemainingTimeEstimate()});
            
            % "Animate" ellipsis
            if isempty(obj.PreviousMessage)
                % Skip
            elseif strcmp( obj.PreviousMessage(end-2:end), '...')
                strMessage(end-1:end) = []; % Remove two dots, one remaining
            elseif strcmp( obj.PreviousMessage(end-1:end), '..')
                % Keep three dots.
            else
                strMessage(end) = []; % Remove last dot, two remaining
            end

            % Split to cell array
            splitIndex = strfind(strMessage, "Estimat")-1;
            if ~isempty(splitIndex)
                strMessage = {extractBefore(strMessage, splitIndex), extractAfter(strMessage, splitIndex)};
            end
        end

        function str = getTransferStatus(obj)
        %getTransferStatus - Return the transferred size and percentage

            % Make past tense action verb, i.e [Download]ed or [Upload]ed
            action = sprintf('%sed', obj.ActionName);

            % The size is unknown when neither the message nor the caller
            % reports it, which is what a message without a body does by
            % reporting 0 bytes. Report the transferred size on its own
            % rather than a total and a percentage that are both NaN.
            if isnan(double(obj.getFileSizeBytes()))
                str = sprintf('%s %d MB.', action, obj.TransferredMb);
                return
            end

            % Create status message. Example: "Downloaded 1 MB/100 MB (1%):
            str = sprintf('%s %d MB/%d MB (%d%%).', action, ...
                obj.TransferredMb, obj.FileSizeMb, round(obj.PercentTransferred));
        end
    
        function str = getRemainingTimeEstimate(obj)
        %getRemainingTimeEstimate - Return the estimated remaining time
            tElapsed = seconds( toc(obj.StartTime) );
            str = obj.formatRemainingTimeEstimate(tElapsed, obj.PercentTransferred);
        end

        function strMessage = getTransferCompletedMessage(obj)
        %getTransferCompletedMessage - Return the message shown when done
            strMessage = obj.getTransferStatus();
            
            tElapsed = seconds( toc(obj.StartTime) );
            tElapsedStr = obj.formatTimeAsString(tElapsed);
            durationMessage = sprintf('Completed in %s. \n', tElapsedStr);

            strMessage = strjoin({strMessage, durationMessage});
        end

        function percentTransferred = computePercentTransferred(obj)
        %computePercentTransferred - Return the percentage of bytes transferred
            fileSizeBytes = obj.getFileSizeBytes();
            percentTransferred = double(obj.Value) / double(fileSizeBytes) * 100;
        end

        function fileSizeMb = getFileSizeMb(obj)
        %getFileSizeMb - Return the file size rounded to megabytes
            fileSizeBytes = obj.getFileSizeBytes();
            fileSizeMb = round( double(fileSizeBytes) / 1024 / 1024 );
        end

        function transferredMb = getTransferredMb(obj)
        %getTransferredMb - Return the transferred size rounded to megabytes
            transferredMb = round( double(obj.Value) / 1024 / 1024 );
        end

        function fileSizeBytes = getFileSizeBytes(obj)
        %getFileSizeBytes - Return the file size in bytes
            if ~isempty(obj.BodySizeBytes)
                fileSizeBytes = obj.BodySizeBytes;
            elseif ~isempty(obj.Max) && obj.Max > 0
                fileSizeBytes = obj.Max;
            else
                fileSizeBytes = obj.FileSizeBytes;
            end
        end
    end

    methods (Static)

        function str = formatRemainingTimeEstimate(tElapsed, percentTransferred)
        %formatRemainingTimeEstimate - Return the remaining time message
        %   Over the first ten seconds the measured transfer rate is too
        %   noisy to extrapolate from. A transfer that has not moved, or
        %   one whose total size is unknown, gives no estimate at all:
        %   the remaining time works out as Inf at zero percent and as
        %   NaN for an unknown size.
            hasUsableRate = seconds(tElapsed) > 10 && percentTransferred > 0;

            if hasUsableRate
                tRemaining = round( (tElapsed ./ percentTransferred) .* (100-percentTransferred) );
                tRemainingStr = ebrains.external.webprogress.FileTransferProgressMonitor.formatTimeAsString(tRemaining);
                str = sprintf('Estimated time remaining: %s...', tRemainingStr);
            else
                str = 'Estimating remaining time...';
            end
        end

        function durationStr = formatTimeAsString(durationValue)
        %formatTimeAsString - Format a duration using its largest whole unit
            if hours(durationValue) > 1
                durationUnit = 'hour';
                durationValueInt = round(hours(durationValue));
            elseif minutes(durationValue) > 1
                durationUnit = 'minute';
                durationValueInt = round(minutes(durationValue));
            else
                durationUnit = 'second';
                durationValueInt = round(seconds(durationValue));
            end
            
            if durationValueInt > 1 % make unit plural
                durationUnit = strcat(durationUnit, 's');
            end

            durationStr = sprintf('%d %s', durationValueInt, durationUnit);
        end

        function shortenedFilename = shortenFilename(filename)
        %shortenFilename - Shorten a long file name with an ellipsis
            filename = char(filename);
            shortenedFilename = [filename(1:12), '...', filename(end-11:end)];
        end
    end

    methods (Static, Access = protected)
        function tf = isWebBasedUIFigure(fig)
        %isWebBasedUIFigure - Return whether FIG can host a uiprogressdlg

            % uiprogressdlg is supported for uifigures or all figures
            % starting from R2025a
            tf = ~isempty(fig) ...
                && isscalar(fig) ...
                && isgraphics(fig, 'figure') ...
                && (isprop(fig, 'isUIFigure') || isMATLABRelease2025aOrNewer());
        end
    end
end

function tf = isMATLABRelease2025aOrNewer()
%isMATLABRelease2025aOrNewer - Return whether MATLAB is R2025a or later
    try
        tf = ~isMATLABReleaseOlderThan("R2025a");
    catch % isMATLABReleaseOlderThan was introduced in R2020b
        tf = false;
    end
end
