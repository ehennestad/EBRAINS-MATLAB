function [actions, isCancelled] = runSyncOnWorker(direction, localFolder, bucketName, options, queues, authorizationField)
% runSyncOnWorker - Run a sync on a background worker, reporting to the MATLAB session
%
%   [actions, isCancelled] = ebrains.bucket.internal.runSyncOnWorker(
%   direction, localFolder, bucketName, options, queues,
%   authorizationField) runs ebrains.bucket.internal.runSync on the
%   worker it is called on. queues is a struct with the fields Progress,
%   the parallel.pool.DataQueue that receives the reports of the sync,
%   and Handshake, a parallel.pool.PollableDataQueue that receives the
%   queue the session sends cancel requests and access tokens to. See
%   ebrains.bucket.internal.WorkerSyncObserver for the messages.
%
%   The worker cannot reach the token manager of the session, so the
%   client sends the Authorization field that the session gives it.
%   Nothing is printed or shown on the worker, where it would not be seen.
%
%   See also ebrains.bucket.SyncJob

    observer = ebrains.bucket.internal.WorkerSyncObserver(queues.Progress, authorizationField);
    send(queues.Handshake, observer.ControlQueue)

    options.Client.AuthorizationFcn = @() observer.authorizationField();
    options.ProgressObserver = observer;
    options.DisplayMode = "None";
    options.Verbose = false;
    [actions, isCancelled] = ebrains.bucket.internal.runSync(direction, localFolder, bucketName, options);
end
