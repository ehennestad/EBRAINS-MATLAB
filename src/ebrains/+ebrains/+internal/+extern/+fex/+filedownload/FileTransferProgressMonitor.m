classdef FileTransferProgressMonitor < matlab.net.http.ProgressMonitor
%FileTransferProgressMonitor Updates a progress monitor for file transfers.
%
%   Create a function handle to provide to matlab.net.http.HTTPOptions:
%       progressMonitorFcn = @FileTransferProgressMonitor;
%
%   Create a function handle to provide to matlab.net.http.HTTPOptions
%   while specifying custom options for the monitor:
%       monitorOptions = {'DisplayMode', 'Command Window'};
%       progressMonitorFcn = @(varargin) FileTransferProgressMonitor(monitorOptions{:})
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
%
%   Bundled copy of filedownload v1.2.0 (web-transfer-progress-monitor).
%   Differs from the release only in calling isWebBasedUIFigure through
%   the instance, since the bare class name does not resolve in a namespace.
    
    properties (SetAccess = private) % User settings for monitor
        DisplayMode = 'Dialog Box'; % Where to display progress.
        UpdateInterval = 1          % Interval (in seconds) for updating progress.
        Filename = ''               % Name of downloaded/uploaded file.
        IndentSize = 0              % Size of indentation (number of spaces) if displaying progress in command window.
        Figure = []                 % Parent figure for uiprogressdlg.
    end

    properties
        FileSizeBytes = nan         % Known file size when ProgressMonitor.Max is not available.
    end

    properties % Implement superclass properties (matlab.net.http.ProgressMonitor)
        Direction matlab.net.http.MessageType
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
    end
    
    methods
        function obj = FileTransferProgressMonitor(varargin)
            
            % Parse optional inputs and assign as property values
            [names, values] = obj.parseVarargin(varargin);
            for i = 1:numel(names)
                if isprop(obj, names{i})
                    obj.(names{i}) = values{i};
                end
            end
            
            obj.Interval = 1;
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
            obj.closeProgressDialog();
            obj.closeWaitbar();
        end
        
        function set.Direction(obj, dir)
            obj.Direction = dir;
            % fprintf('Direction set: %s\n', obj.Direction)
        end
        
        function set.Value(obj, value)
            obj.Value = value;
            obj.update();
        end

        function name = get.ActionName(obj)
            if obj.Direction == matlab.net.http.MessageType.Request
                name = "Upload";
            elseif obj.Direction == matlab.net.http.MessageType.Response
                name = "Download";
            else
                error('Unknown transfer mode')
            end
        end

        function fileSizeMb = get.FileSizeMb(obj)
            fileSizeMb = obj.getFileSizeMb();
        end

        function transferredMb = get.TransferredMb(obj)
            transferredMb = obj.getTransferredMb();
        end

        function percentTransferred = get.PercentTransferred(obj)
            percentTransferred = obj.computePercentTransferred();
        end

        function tf = get.UseWaitbarDialog(obj)
            tf = strcmpi(obj.DisplayMode, 'Dialog Box') ...
                && ~obj.isWebBasedUIFigure(obj.Figure);
        end

        function tf = get.UseUIProgressDialog(obj)
            tf = strcmpi(obj.DisplayMode, 'Dialog Box') ...
                && obj.isWebBasedUIFigure(obj.Figure);
        end

        function tf = get.UseCommandWindow(obj)
            tf = strcmpi(obj.DisplayMode, 'Command Window');
        end
    end
    
    methods (Access = protected)

        function update(obj, ~)
        %update Called when Value is set, handles monitor updating

            import matlab.net.http.*
            
            doUpdate = toc(obj.LastUpdateTime) > obj.UpdateInterval;

            if ~isempty(obj.Value) && doUpdate
                
                if isempty(obj.Max) && isnan(obj.FileSizeBytes)
                    % Maximum (size of request/response) is not known,
                    % file transfer did not start yet.
                    progressValue = 0;
                    msg = sprintf('Waiting for %s to start...', lower(obj.ActionName));
                else
                    % Maximum known, update proportional value
                    progressValue = obj.PercentTransferred / 100;

                    if obj.Direction == MessageType.Request % Sending
                        msg = obj.getProgressMessage();
                        obj.HasTransferStarted = true;

                    elseif obj.Direction == MessageType.Response
                        if ~obj.HasTransferStarted
                            obj.HasTransferStarted = true;
                        end
                        msg = obj.getProgressMessage();
                    else
                        error('Unknown Messagetype')
                    end
                end

                if obj.cancelWasRequested()
                    obj.CancelFcn();
                    obj.closeProgressDialog();
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
                        'CreateCancelBtn', @(~,~) cancelAndClose(obj));
                elseif isempty(obj.PreviousMessage) && obj.UseCommandWindow
                    indentStr = repmat(' ', 1, obj.IndentSize);
                    fprintf('%s%s', indentStr, obj.getProgressTitle() )
                    if ~ischar(msg) && ~isscalar(msg)
                        msg = strjoin(msg, ' ');
                    end
                    obj.updateCommandWindowMessage(msg)
                end

                if obj.HasTransferStarted
                    if obj.UseUIProgressDialog
                        obj.updateProgressDialog(progressValue, msg);
                    elseif obj.UseWaitbarDialog
                        waitbar(progressValue, obj.WaitbarHandle, msg);
                    else
                        obj.updateCommandWindowMessage(msg)
                    end
                end

                obj.LastUpdateTime = tic;
            end
            
            function cancelAndClose(obj)
                % Call the required CancelFcn and then close our progress bar.
                % This is called when user clicks cancel or closes the window.
                obj.CancelFcn();
                obj.closeWaitbar();
            end
        end
        
        function updateCommandWindowMessage(obj, msgStr)
            
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
            if obj.cancelWasRequested()
                obj.CancelFcn();
                obj.closeProgressDialog();
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

        function tf = cancelWasRequested(obj)
            tf = obj.progressDialogIsValid() ...
                && obj.ProgressDialogHandle.CancelRequested;
        end

        function tf = progressDialogIsValid(obj)
            tf = ~isempty(obj.ProgressDialogHandle) ...
                && isvalid(obj.ProgressDialogHandle);
        end

        function closeProgressDialog(obj)
            if ~isempty(obj.ProgressDialogHandle)
                if obj.progressDialogIsValid()
                    close(obj.ProgressDialogHandle);
                end
                obj.ProgressDialogHandle = [];
            end
        end

        function closeWaitbar(obj)
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
            
            % Make ongoing present action verb, i.e [Download]ing or [Upload]ing
            action = sprintf('%sing', obj.ActionName);

            if ~isempty(obj.Filename)
                if numel(char(obj.Filename)) <= 26
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
        %getProgressMessage Get message with information about progress
            
            strMessage = obj.getTransferStatus();
            strRemainingTime = obj.getRemainingTimeEstimate();
            if ~isempty(strRemainingTime)
                strMessage = strjoin({strMessage, strRemainingTime});
            end
            
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
            % Make past tense action verb, i.e [Download]ed or [Upload]ed
            action = sprintf('%sed', obj.ActionName);

            % Create status message. Example: "Downloaded 1 MB/100 MB (1%):
            str = sprintf('%s %d MB/%d MB (%d%%).', action, ...
                obj.TransferredMb, obj.FileSizeMb, round(obj.PercentTransferred));
        end
    
        function str = getRemainingTimeEstimate(obj)
        %getRemainingTimeEstimate Get string with estimated time remaining
            tElapsed = seconds( toc(obj.StartTime) );
            tRemaining = round( (tElapsed ./ obj.PercentTransferred) .* (100-obj.PercentTransferred) );

            if seconds(tElapsed) > 10
                tRemainingStr = obj.formatTimeAsString(tRemaining);
                str = sprintf('Estimated time remaining: %s...', tRemainingStr);
            else
                str = 'Estimating remaining time...';
            end
        end

        function strMessage = getTransferCompletedMessage(obj)
            strMessage = obj.getTransferStatus();
            
            tElapsed = seconds( toc(obj.StartTime) );
            tElapsedStr = obj.formatTimeAsString(tElapsed);
            durationMessage = sprintf('Completed in %s. \n', tElapsedStr);

            strMessage = strjoin({strMessage, durationMessage});
        end

        function percentTransferred = computePercentTransferred(obj)
            fileSizeBytes = obj.getFileSizeBytes();
            percentTransferred = double(obj.Value) / double(fileSizeBytes) * 100;
        end

        function fileSizeMb = getFileSizeMb(obj)
            fileSizeBytes = obj.getFileSizeBytes();
            fileSizeMb = round( double(fileSizeBytes) / 1024 / 1024 );
        end

        function transferredMb = getTransferredMb(obj)
            transferredMb = round( double(obj.Value) / 1024 / 1024 );
        end

        function fileSizeBytes = getFileSizeBytes(obj)
            if ~isempty(obj.Max)
                fileSizeBytes = obj.Max;
            else
                fileSizeBytes = obj.FileSizeBytes;
            end

            if isnan(fileSizeBytes)
                % Todo: Warn once
            end
        end
    end

    methods (Static)

        function [names, values] = parseVarargin(vararginCellArray)
        %parseVarargin Parse varargin (split names and values)
            [names, values] = deal({});
            
            if isempty(vararginCellArray)
                return
            elseif numel(vararginCellArray) == 1 && isstruct(vararginCellArray{1})
                names = fieldnames(vararginCellArray{1});
                values = struct2cell(vararginCellArray{1});
            else
                names = vararginCellArray(1:2:end);
                values = vararginCellArray(2:2:end);
            end
        end
            
        function durationStr = formatTimeAsString(durationValue)
        %formatTimeAsString Format time showing the leading unit.
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
            filename = char(filename);
            shortenedFilename = [filename(1:12), '...', filename(end-11:end)];
        end
    end

    methods (Static, Access = protected)
        function tf = isWebBasedUIFigure(fig)
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
    try
        tf = ~isMATLABReleaseOlderThan("R2025a");
    catch % isMATLABReleaseOlderThan was introduced in R2020b
        tf = false;
    end
end
