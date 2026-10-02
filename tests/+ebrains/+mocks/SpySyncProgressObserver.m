classdef SpySyncProgressObserver < ebrains.bucket.internal.SyncProgressObserver
    % SpySyncProgressObserver - Test double that records the progress a sync reports
    %
    % Records each call in Calls as text, such as "fileStarted 2" or
    % "bytesTransferred 2 3/3", keeps the tables and the error it is given,
    % and asks to cancel once CancelAfterFinishedFiles files have finished.
    %
    % Example:
    %   spy = ebrains.mocks.SpySyncProgressObserver();
    %   spy.CancelAfterFinishedFiles = 1;
    %   ebrains.bucket.syncToBucket(..., ProgressObserver=spy);
    %   spy.Calls

    properties
        % Number of finished files after which isCancelRequested returns true
        CancelAfterFinishedFiles (1,1) double = Inf
    end

    properties (SetAccess = private)
        Calls (:,1) string = string.empty(0, 1) % One line of text per call
        Plan table          % Table given to planReady
        Result table        % Table given to syncFinished
        Error MException = MException.empty % Error given to syncFailed
        NumCancelChecks = 0 % Number of calls of isCancelRequested
    end

    properties (Access = private)
        NumFinished = 0
    end

    methods
        function phaseStarted(obj, phase)
            obj.Calls(end+1) = "phaseStarted " + phase;
        end

        function planReady(obj, actions)
            obj.Plan = actions;
            obj.Calls(end+1) = "planReady";
        end

        function fileStarted(obj, index)
            obj.Calls(end+1) = "fileStarted " + index;
        end

        function bytesTransferred(obj, index, transferredBytes, totalBytes)
            obj.Calls(end+1) = sprintf("bytesTransferred %d %d/%d", index, transferredBytes, totalBytes);
        end

        function fileFinished(obj, index, status, message) %#ok<INUSD>
            obj.NumFinished = obj.NumFinished + 1;
            obj.Calls(end+1) = "fileFinished " + index + " " + status;
        end

        function syncFinished(obj, actions)
            obj.Result = actions;
            obj.Calls(end+1) = "syncFinished";
        end

        function syncFailed(obj, exception)
            obj.Error = exception;
            obj.Calls(end+1) = "syncFailed";
        end

        function tf = isCancelRequested(obj)
            obj.NumCancelChecks = obj.NumCancelChecks + 1;
            tf = obj.NumFinished >= obj.CancelAfterFinishedFiles;
        end
    end
end
