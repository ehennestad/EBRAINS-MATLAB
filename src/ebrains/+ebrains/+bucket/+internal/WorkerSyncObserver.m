classdef (Sealed) WorkerSyncObserver < ebrains.bucket.internal.SyncProgressObserver
% WorkerSyncObserver - Observer of a sync on a background worker, connected to the MATLAB session by queues
%
%   observer = ebrains.bucket.internal.WorkerSyncObserver(progressQueue,
%   authorizationField) is created on the worker. It sends each report of
%   the sync through progressQueue, a parallel.pool.DataQueue of the
%   session, as a struct with the fields Name (the method called) and
%   Arguments (a cell array of its inputs). It reads the messages of the
%   session from ControlQueue, which the worker hands to the session:
%       struct("Type", "cancel")                     - asks to cancel
%       struct("Type", "authorization", "Field", F)  - the Authorization
%                                                      header field to
%                                                      send from now on,
%                                                      or [] for none
%   authorizationField is the field to send until the first such message.
%
%   See also ebrains.bucket.SyncJob, ebrains.bucket.internal.runSyncOnWorker

    properties (SetAccess = private)
        ControlQueue        % parallel.pool.PollableDataQueue that the session sends to
        IsCancelRequested (1,1) logical = false % Whether the session asked to cancel
    end

    properties (Access = private)
        ProgressQueue       % parallel.pool.DataQueue of the session
        AuthorizationField  % Field to send with each request, or []
    end

    methods
        function obj = WorkerSyncObserver(progressQueue, authorizationField)
            % A PollableDataQueue can be polled only where it was created,
            % so the worker creates the queue it reads.
            obj.ControlQueue = parallel.pool.PollableDataQueue;
            obj.ProgressQueue = progressQueue;
            obj.AuthorizationField = authorizationField;
        end

        function phaseStarted(obj, phase)
            obj.forward("phaseStarted", phase)
        end

        function planReady(obj, actions)
            obj.forward("planReady", actions)
        end

        function fileStarted(obj, index)
            obj.forward("fileStarted", index)
        end

        function bytesTransferred(obj, index, transferredBytes, totalBytes)
            obj.forward("bytesTransferred", index, transferredBytes, totalBytes)
        end

        function fileFinished(obj, index, status, message)
            obj.forward("fileFinished", index, status, message)
        end

        function syncFinished(obj, actions)
            obj.forward("syncFinished", actions)
        end

        function syncFailed(obj, exception)
            obj.forward("syncFailed", exception)
        end

        function tf = isCancelRequested(obj)
            obj.readControlQueue()
            tf = obj.IsCancelRequested;
        end

        function field = authorizationField(obj)
        % authorizationField - The Authorization header field the session sent last, or []
            obj.readControlQueue()
            field = obj.AuthorizationField;
        end
    end

    methods (Access = private)
        function forward(obj, name, varargin)
            send(obj.ProgressQueue, struct("Name", name, "Arguments", {varargin}))
        end

        function readControlQueue(obj)
        % readControlQueue - Take in every message the session has sent
            [message, hasMessage] = poll(obj.ControlQueue);
            while hasMessage
                switch message.Type
                    case "cancel"
                        obj.IsCancelRequested = true;
                    case "authorization"
                        obj.AuthorizationField = message.Field;
                    otherwise
                        % ebrains.bucket.SyncJob sends no other message.
                end
                [message, hasMessage] = poll(obj.ControlQueue);
            end
        end
    end
end
