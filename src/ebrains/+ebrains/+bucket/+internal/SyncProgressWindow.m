classdef (Sealed) SyncProgressWindow < ebrains.bucket.internal.SyncProgressObserver
% SyncProgressWindow - Window that shows the progress of a bucket sync
%
%   window = ebrains.bucket.internal.SyncProgressWindow(description) opens
%   a window for a sync that ebrains.bucket.internal.runSync reports to,
%   with description as its heading. runSync opens one when a sync runs
%   with DisplayMode "Window". The window shows
%       - a bar and a line for the whole sync: the files and bytes
%         copied, and an estimate of the time left;
%       - a table with one row per file to copy or delete, with a bar and
%         a status for each;
%       - a Cancel button, which becomes Close once the sync is done.
%
%   The sync runs in the MATLAB thread, so the window is redrawn, and a
%   press of Cancel is noticed, only when the sync reports progress. A
%   transfer reports about once a second, and runSync asks whether to
%   cancel before each file. Closing the window while the sync runs
%   cancels it, as Cancel does.
%
%   See also ebrains.bucket.internal.SyncProgressObserver,
%   ebrains.bucket.syncToBucket, ebrains.bucket.syncFromBucket

    properties (SetAccess = private)
        Figure          % The uifigure of the window
        SummaryLabel    % Line under the total bar with the files, bytes and time left
        FileTable       % Table with one row per file to copy or delete
        CancelButton    % Button that cancels the sync, and closes the window once it is done
        IsCancelRequested (1,1) logical = false % Whether the user asked to cancel
        IsFinished (1,1) logical = false        % Whether the sync is done or stopped by an error
    end

    properties (Access = private)
        TotalBarGrid            % Grid whose two column widths draw the total bar
        Actions table           % The plan, and at the end the result, of the sync
        TableRows double        % Row of FileTable for each row of Actions, 0 for a file without action
        NumCopies = 0           % Number of files to copy
        NumCopiesFinished = 0   % Number of files whose copy is done, failed or cancelled
        CopyBytes = 0           % Bytes of the files to copy
        FinishedBytes = 0       % Bytes of the files whose copy is finished
        CurrentBytes = 0        % Bytes so far of the file being copied
        CopyStartTime           % tic when copying started, for the time estimate
    end

    properties (Constant, Access = private)
        BarColor = [0.231, 0.490, 0.847]
        TrackColor = [0.867, 0.867, 0.867]
        DoneColor = [0.871, 0.953, 0.871]
        FailedColor = [0.992, 0.871, 0.871]
        SkippedColor = [0.5, 0.5, 0.5]
        ErrorTextColor = [0.75, 0.1, 0.1]

        % The column widths of the total bar are weights out of this
        % number, as uigridlayout spreads "x" widths in proportion.
        BarResolution = 1000

        % Before this many seconds the transfer rate is too uncertain to
        % estimate the time left from.
        MinimumEstimateSeconds = 3
    end

    methods
        function obj = SyncProgressWindow(description)
            arguments
                description (1,1) string = "Syncing."
            end

            obj.Figure = uifigure(Name="EBRAINS bucket sync", ...
                CloseRequestFcn=@(~, ~) obj.onCancelOrClose());
            obj.Figure.Position(3:4) = [760, 480];

            grid = uigridlayout(obj.Figure, [5, 1], ...
                RowHeight={"fit", 12, "fit", "1x", "fit"});
            uilabel(grid, Text=description, FontWeight="bold", WordWrap="on");

            obj.TotalBarGrid = uigridlayout(grid, [1, 2], Padding=0, ...
                ColumnSpacing=0, RowSpacing=0, ColumnWidth={0, "1x"});
            uipanel(obj.TotalBarGrid, BackgroundColor=obj.BarColor, BorderType="none");
            uipanel(obj.TotalBarGrid, BackgroundColor=obj.TrackColor, BorderType="none");

            obj.SummaryLabel = uilabel(grid, Text="Starting...", WordWrap="on");

            obj.FileTable = uitable(grid, ...
                ColumnName=["Path", "Action", "Size", "Progress", "Status"], ...
                ColumnWidth={"2x", 75, 75, 130, "1x"}, RowName={});
            % Only a table cell renders the HTML of the progress bars; the
            % HTML of a uilabel leaves out tables.
            addStyle(obj.FileTable, uistyle(Interpreter="html"), "column", 4)

            buttonGrid = uigridlayout(grid, [1, 2], Padding=0, ColumnWidth={"1x", 100});
            obj.CancelButton = uibutton(buttonGrid, Text="Cancel", ...
                ButtonPushedFcn=@(~, ~) obj.onCancelOrClose());
            obj.CancelButton.Layout.Column = 2;

            drawnow
        end

        function phaseStarted(obj, phase)
            if ~obj.isOpen()
                return
            end
            switch phase
                case "listing"
                    obj.SummaryLabel.Text = "Listing files...";
                case "checksums"
                    obj.SummaryLabel.Text = "Computing checksums of local files...";
                case "copying"
                    obj.CopyStartTime = tic;
                    obj.updateTotals()
                case "deleting"
                    obj.SummaryLabel.Text = "Deleting files...";
                otherwise
                    % runSync starts no other phase. An unknown one has
                    % nothing to show.
            end
            drawnow limitrate
        end

        function planReady(obj, actions)
            obj.Actions = actions;
            if ~obj.isOpen()
                return
            end

            isShown = actions.Action ~= "none";
            isCopy = isShown & actions.Action ~= "delete";
            obj.NumCopies = sum(isCopy);
            obj.CopyBytes = sum(actions.Bytes(isCopy));
            obj.TableRows = zeros(height(actions), 1);
            obj.TableRows(isShown) = 1:sum(isShown);

            shown = actions(isShown, :);
            sizes = arrayfun(@ebrains.bucket.internal.formatBytes, shown.Bytes, ...
                UniformOutput=false);
            progress = repmat("", height(shown), 1);
            progress(shown.Action ~= "delete") = obj.progressBar(0);
            obj.FileTable.Data = table(shown.Path, shown.Action, string(sizes), ...
                progress, repmat("queued", height(shown), 1), ...
                VariableNames=["Path", "Action", "Size", "Progress", "Status"]);

            obj.SummaryLabel.Text = sprintf( ...
                "%d file(s) to copy (%s), %d to delete, %d unchanged.", ...
                obj.NumCopies, ebrains.bucket.internal.formatBytes(obj.CopyBytes), ...
                sum(actions.Action == "delete"), sum(actions.Reason == "unchanged"));
            drawnow
        end

        function fileStarted(obj, index)
            row = obj.TableRows(index);
            if ~obj.isOpen() || row == 0
                return
            end
            obj.CurrentBytes = 0;
            obj.setStatus(row, presentParticiple(obj.Actions.Action(index)) + "...")
            scroll(obj.FileTable, "row", row)
            drawnow limitrate
        end

        function bytesTransferred(obj, index, transferredBytes, totalBytes)
            row = obj.TableRows(index);
            if ~obj.isOpen() || row == 0
                return
            end
            % The plan knows the size when the transfer does not.
            if isnan(totalBytes) || totalBytes == 0
                totalBytes = obj.Actions.Bytes(index);
            end
            fraction = min(transferredBytes / max(totalBytes, 1), 1);
            obj.CurrentBytes = transferredBytes;
            obj.FileTable.Data.Progress(row) = obj.progressBar(fraction);
            obj.setStatus(row, sprintf("%d%%", round(100*fraction)))
            obj.updateTotals()
            drawnow limitrate
        end

        function fileFinished(obj, index, status, message)
            row = obj.TableRows(index);
            if ~obj.isOpen() || row == 0
                return
            end
            if obj.Actions.Action(index) ~= "delete"
                obj.NumCopiesFinished = obj.NumCopiesFinished + 1;
                obj.FinishedBytes = obj.FinishedBytes + obj.Actions.Bytes(index);
                obj.CurrentBytes = 0;
                if status == "done"
                    obj.FileTable.Data.Progress(row) = obj.progressBar(1);
                end
            end
            obj.showResult(row, status, message)
            obj.updateTotals()
            drawnow limitrate
        end

        function syncFinished(obj, actions)
            obj.IsFinished = true;
            if ~obj.isOpen()
                return
            end

            % The files the sync skipped or only planned were never
            % started, so their rows still say "queued".
            isUnstarted = ismember(actions.Status, ["skipped", "planned"]) & obj.TableRows > 0;
            for index = reshape(find(isUnstarted), 1, [])
                obj.showResult(obj.TableRows(index), actions.Status(index), actions.Message(index))
            end

            isCopy = actions.Action ~= "none" & actions.Action ~= "delete";
            isDelete = actions.Action == "delete";
            obj.SummaryLabel.Text = sprintf( ...
                "Done: %d copied, %d deleted, %d failed, %d cancelled or skipped.", ...
                sum(isCopy & actions.Status == "done"), ...
                sum(isDelete & actions.Status == "done"), ...
                sum(actions.Status == "failed"), ...
                sum(ismember(actions.Status, ["cancelled", "skipped"])));
            if any(actions.Status == "planned")
                obj.SummaryLabel.Text = "Dry run: nothing was changed. " + ...
                    sprintf("%d file(s) would be copied and %d deleted.", sum(isCopy), sum(isDelete));
            end
            obj.CancelButton.Text = "Close";
            obj.CancelButton.Enable = "on";
            drawnow
        end

        function syncFailed(obj, exception)
            obj.IsFinished = true;
            if ~obj.isOpen()
                return
            end
            obj.SummaryLabel.Text = "The sync stopped with an error: " + exception.message;
            obj.SummaryLabel.FontColor = obj.ErrorTextColor;
            obj.CancelButton.Text = "Close";
            obj.CancelButton.Enable = "on";
            drawnow
        end

        function tf = isCancelRequested(obj)
            % The Cancel button's callback runs only when the event queue
            % is processed, which the blocking sync does not do by itself.
            if obj.isOpen()
                drawnow limitrate
            end
            tf = obj.IsCancelRequested;
        end
    end

    methods (Access = private)
        function onCancelOrClose(obj)
        % onCancelOrClose - Cancel a running sync, or close the window of a finished one
            if obj.IsFinished
                delete(obj.Figure)
                return
            end
            obj.IsCancelRequested = true;
            obj.CancelButton.Text = "Cancelling...";
            obj.CancelButton.Enable = "off";
            obj.SummaryLabel.Text = "Cancelling: stopping the file in progress...";
        end

        function updateTotals(obj)
        % updateTotals - Redraw the total bar and the summary line
            doneBytes = obj.FinishedBytes + obj.CurrentBytes;
            fraction = doneBytes / max(obj.CopyBytes, 1);
            obj.setTotalBar(fraction)
            if obj.IsCancelRequested
                return
            end
            obj.SummaryLabel.Text = sprintf("%d/%d files, %s/%s%s", ...
                obj.NumCopiesFinished, obj.NumCopies, ...
                ebrains.bucket.internal.formatBytes(doneBytes), ...
                ebrains.bucket.internal.formatBytes(obj.CopyBytes), ...
                obj.formatTimeLeft(doneBytes));
        end

        function setTotalBar(obj, fraction)
        % setTotalBar - Show fraction, from 0 to 1, of the total bar as filled
            filled = round(obj.BarResolution * min(max(fraction, 0), 1));
            if filled == 0
                obj.TotalBarGrid.ColumnWidth = {0, "1x"};
            elseif filled == obj.BarResolution
                obj.TotalBarGrid.ColumnWidth = {"1x", 0};
            else
                obj.TotalBarGrid.ColumnWidth = {sprintf("%dx", filled), ...
                    sprintf("%dx", obj.BarResolution - filled)};
            end
        end

        function text = formatTimeLeft(obj, doneBytes)
        % formatTimeLeft - Estimate of the time left, from the rate so far, or ""
            text = "";
            if isempty(obj.CopyStartTime) || doneBytes == 0
                return
            end
            elapsedSeconds = toc(obj.CopyStartTime);
            if elapsedSeconds < obj.MinimumEstimateSeconds
                return
            end
            secondsLeft = elapsedSeconds * (obj.CopyBytes - doneBytes) / doneBytes;
            if secondsLeft < 60
                text = sprintf(", about %d s left", ceil(secondsLeft));
            elseif secondsLeft < 3600
                text = sprintf(", about %d min left", ceil(secondsLeft / 60));
            else
                text = sprintf(", about %.1f h left", secondsLeft / 3600);
            end
        end

        function showResult(obj, row, status, message)
        % showResult - Show the status of a finished file and colour its row
        %   Only the message of a failure is shown, because it differs
        %   from file to file. The summary line says why files were
        %   cancelled or skipped.
            statusText = status;
            if status == "failed" && strlength(message) > 0
                statusText = status + ": " + message;
            end
            obj.setStatus(row, statusText)
            switch status
                case "done"
                    style = uistyle(BackgroundColor=obj.DoneColor);
                case {"failed", "cancelled"}
                    style = uistyle(BackgroundColor=obj.FailedColor);
                otherwise
                    style = uistyle(FontColor=obj.SkippedColor);
            end
            addStyle(obj.FileTable, style, "row", row)
        end

        function setStatus(obj, row, text)
        % setStatus - Show text in the Status column of a row
            obj.FileTable.Data.Status(row) = text;
        end

        function html = progressBar(obj, fraction)
        % progressBar - HTML of a bar filled to fraction, for a table cell
        %   The bar is a table of two cells, because the HTML that a table
        %   cell renders has no div or span elements. A cell needs its
        %   height in its style; an empty cell is drawn without height
        %   otherwise.
            html = sprintf(['<table style="width:100%%;border-collapse:collapse"><tr>' ...
                '<td style="width:%d%%;background-color:%s;height:8px;padding:0"></td>' ...
                '<td style="background-color:%s;padding:0"></td></tr></table>'], ...
                round(100*fraction), rgb2hex(obj.BarColor), rgb2hex(obj.TrackColor));
        end

        function tf = isOpen(obj)
        % isOpen - Return whether the window is still there to update
        %   Closing the window only cancels a running sync, but the
        %   figure can still be deleted by other means, such as
        %   "close all force".
            tf = isvalid(obj.Figure);
        end
    end
end

function text = presentParticiple(action)
% presentParticiple - "uploading", "downloading" or "deleting" for an action
    if endsWith(action, "e")
        action = extractBefore(action, strlength(action));
    end
    text = action + "ing";
end

function hex = rgb2hex(color)
% rgb2hex - CSS colour, such as "#3b7dd8", of an RGB triplet from 0 to 1
    hex = sprintf("#%02x%02x%02x", round(255*color));
end
