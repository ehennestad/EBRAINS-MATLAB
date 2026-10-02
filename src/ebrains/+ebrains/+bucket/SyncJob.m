classdef (Sealed) SyncJob < handle
% SyncJob - A bucket sync that runs in the background
%
%   job = ebrains.bucket.syncToBucket(..., Background=true) and
%   job = ebrains.bucket.syncFromBucket(..., Background=true) start the
%   sync on a thread-based worker of backgroundPool and return a SyncJob
%   at once, so MATLAB stays free while files are copied.
%
%   SyncJob properties:
%       State   - "running", then "finished", "cancelled" (stopped by
%                 cancel, with the table of what was done), "stopped"
%                 (stopped by stop, without a table) or "failed"
%       Actions - Table the sync returns, once State is "finished" or
%                 "cancelled". syncToBucket describes it.
%       Error   - Error that ended the sync, when State is "failed" or
%                 "stopped"
%
%   SyncJob methods:
%       wait   - Wait for the sync to end and return its table
%       cancel - Stop after the transfer in progress, keeping the table
%       stop   - Stop at once, also a transfer that has stalled
%
%   With DisplayMode "Window", the progress window shows the job. Its
%   Cancel button cancels the job; if the worker has not stopped
%   StopAfterSeconds later, because a transfer has stalled, the job is
%   stopped. The warnings of an incomplete sync are raised in the MATLAB
%   session when the job ends.
%
%   The worker cannot reach the token manager of the session, so the job
%   sends it the access token, and a renewed one every minute.
%
%   Example:
%       job = ebrains.bucket.syncFromBucket("my-bucket", "data", ...
%           DisplayMode="Window", Background=true);
%       % ... work on in MATLAB ...
%       actions = wait(job);
%
%   See also ebrains.bucket.syncToBucket, ebrains.bucket.syncFromBucket

    properties (SetAccess = private)
        State (1,1) string = "running" % "running", "finished", "cancelled", "stopped" or "failed"
        Actions table = table.empty    % Table the sync returns, once it has ended normally
        Error MException = MException.empty % Error that ended the sync
    end

    properties (Constant)
        % Seconds after a cancel before the job is stopped at once
        StopAfterSeconds = 10
    end

    properties (Access = private)
        Future                  % parallel.FevalFuture of the sync on the worker
        ControlQueue            % Queue the worker reads cancel requests and tokens from
        ProgressQueue           % Queue the worker sends its reports to
        Observer                % Observer in the session: the window, or the given one
        Timer                   % Checks the observer for a cancel and renews the token
        CancelTime = []         % tic of the cancel request, [] before
        LastAuthorizationTime   % tic of the last token sent to the worker
        IsStopRequested (1,1) logical = false
        IsReportComplete (1,1) logical = false % Whether the last report of the worker has arrived
    end

    properties (Constant, Access = private)
        HandshakeTimeoutSeconds = 60

        % Longest wait for the last report of the worker after the job
        % ended. A sync that fails before it starts reports nothing.
        ReportTimeoutSeconds = 2
        AuthorizationIntervalSeconds = 60
        TimerPeriodSeconds = 0.25
    end

    methods
        function obj = SyncJob(direction, localFolder, bucketName, options)
        % SyncJob - Start a sync in the background
        %   job = ebrains.bucket.SyncJob(direction, localFolder,
        %   bucketName, options) is called by syncToBucket and
        %   syncFromBucket with their options.
            arguments
                direction (1,1) string {mustBeMember(direction, ["ToBucket", "FromBucket"])}
                localFolder (1,1) string
                bucketName (1,1) string
                options (1,1) struct
            end

            if options.DisplayMode == "Window"
                prefix = ebrains.bucket.internal.normalizePrefix(options.Prefix);
                obj.Observer = ebrains.bucket.internal.SyncProgressWindow( ...
                    ebrains.bucket.internal.describeSync(direction, localFolder, bucketName, prefix));
            else
                obj.Observer = options.ProgressObserver;
            end
            % The observer stays in the session; a figure cannot go to a
            % thread-based worker.
            options.ProgressObserver = ebrains.bucket.internal.SyncProgressObserver();

            obj.ProgressQueue = parallel.pool.DataQueue;
            afterEach(obj.ProgressQueue, @(message) obj.relay(message));
            handshakeQueue = parallel.pool.PollableDataQueue;
            queues = struct("Progress", obj.ProgressQueue, "Handshake", handshakeQueue);

            authorizationField = currentAuthorizationField(ebrains.getpref("AutoLogin"));
            obj.LastAuthorizationTime = tic;
            obj.Future = parfeval(backgroundPool, @ebrains.bucket.internal.runSyncOnWorker, 2, ...
                direction, localFolder, bucketName, options, queues, authorizationField);

            [obj.ControlQueue, isReceived] = poll(handshakeQueue, obj.HandshakeTimeoutSeconds);
            if ~isReceived
                obj.raiseStartFailure()
            end

            afterEach(obj.Future, @(future) obj.onFutureDone(future), 0, PassFuture=true);
            obj.Timer = timer(Name="EBRAINS sync job", ExecutionMode="fixedSpacing", ...
                Period=obj.TimerPeriodSeconds, TimerFcn=@(~, ~) obj.onTimer());
            start(obj.Timer)
        end

        function actions = wait(obj)
        % wait - Wait for the sync to end and return its table
        %   actions = wait(job) returns the table of the sync once it has
        %   finished or been cancelled, and raises the error that ended
        %   it when it failed or was stopped.
            % pause lets the reports of the worker and the end of the job
            % through, which a blocking wait on the future would hold back.
            while obj.State == "running"
                pause(0.05)
            end
            % The job can end before the session has taken in the last
            % reports of the worker, which the observer is still to get.
            endTime = tic;
            while ~obj.IsReportComplete && toc(endTime) < obj.ReportTimeoutSeconds
                pause(0.05)
            end
            if ismember(obj.State, ["failed", "stopped"])
                throw(obj.Error)
            end
            actions = obj.Actions;
        end

        function cancel(obj)
        % cancel - Stop the sync after the transfer in progress
        %   cancel(job) asks the worker to cancel the file in progress
        %   and to skip the rest, as the Cancel button does. The job
        %   ends with State "cancelled" and the table of what was done.
            if obj.State == "running" && isempty(obj.CancelTime)
                send(obj.ControlQueue, struct("Type", "cancel"))
                obj.CancelTime = tic;
            end
        end

        function stop(obj)
        % stop - Stop the sync at once
        %   stop(job) ends the worker, also in a transfer that has
        %   stalled, which cancel waits for. The job ends with State
        %   "stopped" and no table. Run the sync again to finish it.
            if obj.State == "running"
                obj.IsStopRequested = true;
                cancel(obj.Future)
            end
        end

        function delete(obj)
            obj.deleteTimer()
        end
    end

    methods (Access = private)
        function relay(obj, message)
        % relay - Pass a report of the worker on to the observer in the session
            obj.Observer.(message.Name)(message.Arguments{:});
            if ismember(message.Name, ["syncFinished", "syncFailed"])
                obj.IsReportComplete = true;
            end
        end

        function onTimer(obj)
        % onTimer - Forward a cancel from the window, stop a cancel that hangs, and renew the token
            if obj.State ~= "running"
                return
            end
            if isempty(obj.CancelTime) && obj.Observer.isCancelRequested()
                obj.cancel()
            end
            if ~isempty(obj.CancelTime) && toc(obj.CancelTime) > obj.StopAfterSeconds
                obj.stop()
                return
            end
            if toc(obj.LastAuthorizationTime) > obj.AuthorizationIntervalSeconds
                % No login is started from a timer; the token manager
                % renews a token it holds, which is what is needed here.
                send(obj.ControlQueue, struct("Type", "authorization", ...
                    "Field", currentAuthorizationField(false)))
                obj.LastAuthorizationTime = tic;
            end
        end

        function onFutureDone(obj, future)
        % onFutureDone - Record how the sync ended
            obj.deleteTimer()
            if isempty(future.Error)
                [obj.Actions, isCancelled] = fetchOutputs(future);
                if isCancelled
                    obj.State = "cancelled";
                else
                    obj.State = "finished";
                end
                ebrains.bucket.internal.warnIfIncomplete(obj.Actions, isCancelled)
            elseif obj.IsStopRequested
                obj.State = "stopped";
                obj.Error = MException('EBRAINS:Bucket:Sync:Stopped', ...
                    ['The sync was stopped before it finished, so it returned no table. ' ...
                     'Run it again to finish it; files that are already copied are not copied again.']);
                obj.Observer.syncFailed(obj.Error)
                obj.IsReportComplete = true;
            else
                % runSync has reported the error to the observer already.
                obj.State = "failed";
                obj.Error = workerError(future);
            end
        end

        function raiseStartFailure(obj)
        % raiseStartFailure - Raise why the worker did not start the sync
            obj.Observer.syncFailed(MException('EBRAINS:Bucket:Sync:NotStarted', ...
                'The background worker did not start the sync.'))
            if obj.Future.State == "finished" && ~isempty(obj.Future.Error)
                throw(workerError(obj.Future))
            end
            cancel(obj.Future)
            error('EBRAINS:Bucket:Sync:NotStarted', ...
                'The background worker did not start the sync within %d seconds.', ...
                obj.HandshakeTimeoutSeconds)
        end

        function deleteTimer(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer)
                delete(obj.Timer)
            end
        end
    end
end

function field = currentAuthorizationField(isInteractive)
% currentAuthorizationField - Authorization field of the session, or [] without a token
%   This is the field ebrains.common.internal.HttpClient sends with a
%   request in the session.
    tokenManager = ebrains.getTokenManager(Interactive=isInteractive);
    if isempty(tokenManager)
        field = [];
    else
        field = tokenManager.getAuthHeaderField();
    end
end

function exception = workerError(future)
% workerError - The error raised on the worker, rather than its wrapper
    exception = future.Error;
    if isprop(exception, "remotecause") && ~isempty(exception.remotecause)
        exception = exception.remotecause{1};
    end
end
