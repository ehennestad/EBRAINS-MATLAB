classdef (Sealed) DownloadProgress < handle
% DownloadProgress - Show the progress of a download of several files in one progress dialog
%
%   progress = ebrains.bucket.app.internal.DownloadProgress(dialog,
%   fileBytes) shows the progress of a download of numel(fileBytes) files
%   in the uiprogressdlg dialog. fileBytes holds the size of each file in
%   bytes, in the order the files are downloaded, with NaN for a size
%   that is not known.
%
%   The caller reports each file in turn:
%       progress.startFile(name)          - The download of the next file,
%                                           shown as name, starts.
%       progress.reportBytes(nBytes)      - nBytes of that file have
%                                           arrived so far.
%       progress.finishFile(isDownloaded) - The download of that file
%                                           ended; isDownloaded is false
%                                           for a file that failed.
%
%   When every size is known, the bar shows the bytes downloaded out of
%   the bytes of all files, and the bytes of the file in progress count
%   as they arrive. The size of a file that failed is taken out of the
%   total, so the bar is full when every other file is downloaded. When a
%   size is unknown, the bar shows the number of files finished out of
%   the number of files. The message has three lines: the number of the
%   file in progress, the name of that file, and the bytes downloaded with
%   an estimate of the time left from the rate so far.
%
%   tf = progress.isCancelRequested() returns true when the user has
%   pressed Cancel in the dialog, or the dialog has been deleted, as when
%   its window is closed.
%
%   progress = ebrains.bucket.app.internal.DownloadProgress(...,
%   Name=Value) sets the options below.
%
%   Name-Value Arguments
%       UpdateInterval         : Least number of seconds between two
%                                redraws of the dialog. Default is 0.2. A
%                                redraw processes the events of MATLAB,
%                                which costs more than the download of a
%                                small file, so a report within the
%                                interval is kept but not drawn.
%       MinimumEstimateSeconds : Seconds from the start before the time
%                                left is estimated. Default is 3, since
%                                the rate of the first seconds says
%                                little about the rest.
%
%   See also ebrains.bucket.app.internal.ListingProgress, uiprogressdlg

    properties (SetAccess = private)
        % Dialog - The progress dialog, or an object with its Message, Value and CancelRequested properties
        Dialog

        % FileBytes - Size of each file in bytes, NaN where it is not known
        FileBytes (:,1) double

        % TotalBytes - Bytes of the files that are downloaded or still to download, NaN if a size is unknown
        TotalBytes (1,1) double

        % NumFinished - Number of files whose download ended, downloaded or failed
        NumFinished (1,1) double = 0

        % DownloadedBytes - Bytes of the files that are downloaded
        DownloadedBytes (1,1) double = 0

        % CurrentBytes - Bytes that have arrived of the file in progress
        CurrentBytes (1,1) double = 0

        % CurrentName - Name of the file in progress, "" before the first file
        CurrentName (1,1) string = ""
    end

    properties (Access = private)
        UpdateInterval (1,1) double
        MinimumEstimateSeconds (1,1) double
        StartTime (1,1) uint64

        % LastRedrawTime - Timer started at the last redraw, empty before the first
        LastRedrawTime uint64 {mustBeScalarOrEmpty}
    end

    properties (Constant, Access = private)
        % MaxNameLength - Characters of a file name shown before it is shortened from the left
        MaxNameLength = 60
    end

    methods
        function progress = DownloadProgress(dialog, fileBytes, options)
            arguments
                dialog
                fileBytes (:,1) double
                options.UpdateInterval (1,1) double {mustBeNonnegative} = 0.2
                options.MinimumEstimateSeconds (1,1) double {mustBeNonnegative} = 3
            end
            progress.Dialog = dialog;
            progress.FileBytes = fileBytes;
            progress.TotalBytes = sum(fileBytes);
            progress.UpdateInterval = options.UpdateInterval;
            progress.MinimumEstimateSeconds = options.MinimumEstimateSeconds;
            progress.StartTime = tic;
        end

        function startFile(progress, name)
            arguments
                progress
                name (1,1) string
            end
            progress.CurrentName = name;
            progress.CurrentBytes = 0;
            progress.redraw()
        end

        function reportBytes(progress, nBytes)
            arguments
                progress
                nBytes (1,1) double
            end
            progress.CurrentBytes = nBytes;
            progress.redraw()
        end

        function finishFile(progress, isDownloaded)
            arguments
                progress
                isDownloaded (1,1) logical
            end
            listedBytes = progress.FileBytes(progress.NumFinished + 1);
            if isDownloaded
                if isnan(listedBytes)
                    progress.DownloadedBytes = progress.DownloadedBytes + progress.CurrentBytes;
                else
                    progress.DownloadedBytes = progress.DownloadedBytes + listedBytes;
                end
            else
                % NaN stays NaN, so this only changes a total that is known
                progress.TotalBytes = progress.TotalBytes - listedBytes;
            end
            progress.CurrentBytes = 0;
            progress.NumFinished = progress.NumFinished + 1;
            progress.redraw()
        end

        function tf = isCancelRequested(progress)
            % A click on Cancel reaches the dialog only when MATLAB
            % processes its events, which a redraw does.
            progress.redraw()
            tf = ~isvalid(progress.Dialog) || progress.Dialog.CancelRequested;
        end
    end

    methods (Access = private)
        function redraw(progress)
        % redraw - Show the current state in the dialog, unless the last redraw was within UpdateInterval
            if ~isvalid(progress.Dialog)
                return
            end
            isDue = isempty(progress.LastRedrawTime) ...
                || toc(progress.LastRedrawTime) >= progress.UpdateInterval;
            if ~isDue
                return
            end

            progress.Dialog.Value = progress.fractionDone();
            progress.Dialog.Message = progress.describe();
            drawnow
            progress.LastRedrawTime = tic;
        end

        function tf = isMeasuredInBytes(progress)
        % isMeasuredInBytes - Whether the bar shows bytes, which needs a known total above zero
            tf = ~isnan(progress.TotalBytes) && progress.TotalBytes > 0;
        end

        function fraction = fractionDone(progress)
            if progress.isMeasuredInBytes()
                arrivedBytes = progress.DownloadedBytes + progress.CurrentBytes;
                fraction = min(arrivedBytes / progress.TotalBytes, 1);
            else
                fraction = progress.NumFinished / max(numel(progress.FileBytes), 1);
            end
        end

        function message = describe(progress)
        % describe - The message of the dialog: a line each for the file number, the file name and the bytes
            nFiles = numel(progress.FileBytes);
            fileNumber = min(progress.NumFinished + 1, nFiles);
            messageLines = sprintf("Downloading file %s of %s.", formatCount(fileNumber), formatCount(nFiles));

            if progress.CurrentName ~= ""
                messageLines(end+1) = shortenFromLeft(progress.CurrentName, progress.MaxNameLength);
            end

            arrivedText = ebrains.bucket.app.internal.formatBytes(progress.DownloadedBytes + progress.CurrentBytes);
            if progress.isMeasuredInBytes()
                bytesLine = sprintf("%s of %s downloaded.", ...
                    arrivedText, ebrains.bucket.app.internal.formatBytes(progress.TotalBytes));
            else
                bytesLine = sprintf("%s downloaded.", arrivedText);
            end
            secondsLeft = progress.estimateSecondsLeft();
            if ~isnan(secondsLeft)
                bytesLine = bytesLine + " About " + formatDuration(secondsLeft) + " left.";
            end
            messageLines(end+1) = bytesLine;

            message = join(messageLines, newline);
        end

        function secondsLeft = estimateSecondsLeft(progress)
        % estimateSecondsLeft - Time left at the rate so far, NaN while there is nothing to estimate from
            secondsLeft = NaN;
            secondsElapsed = toc(progress.StartTime);
            if secondsElapsed < progress.MinimumEstimateSeconds
                return
            end

            if progress.isMeasuredInBytes()
                amountDone = progress.DownloadedBytes + progress.CurrentBytes;
                amountLeft = progress.TotalBytes - amountDone;
            else
                amountDone = progress.NumFinished;
                amountLeft = numel(progress.FileBytes) - amountDone;
            end
            if amountDone > 0 && amountLeft > 0
                secondsLeft = secondsElapsed / amountDone * amountLeft;
            end
        end
    end
end

function text = shortenFromLeft(text, maxLength)
% shortenFromLeft - Text of at most maxLength characters, with "..." in place of the start of a longer one
%
%   The end of a path is kept, since it holds the file name.
    ellipsis = "...";
    if strlength(text) > maxLength
        text = ellipsis + extractAfter(text, strlength(text) - (maxLength - strlength(ellipsis)));
    end
end
