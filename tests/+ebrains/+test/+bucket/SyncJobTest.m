classdef SyncJobTest < matlab.unittest.TestCase
    % SyncJobTest - Tests of syncs that run in the background
    %
    % The syncs run on backgroundPool with MockBucketsClient and stand-ins
    % for the uploader, as in SyncTest. The mock client is copied to the
    % worker, so the requests it records there are not visible here; the
    % tests check the table, the state of the job and the reports that
    % reach the session.

    properties
        Folder string
        Client ebrains.mocks.MockBucketsClient
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            testCase.Folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.Client = ebrains.mocks.MockBucketsClient();
        end
    end

    methods (Test)
        function testBackgroundSyncReturnsJobAndReportsToObserver(testCase)
            writeFiles(testCase.Folder, ["a.txt", "b.txt"]);
            queueEmptyListingAndUrls(testCase.Client, 2);
            spy = ebrains.mocks.SpySyncProgressObserver();

            job = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Background=true, Uploader=@acceptingUploader, ...
                ProgressObserver=spy, Client=testCase.Client);
            testCase.verifyClass(job, 'ebrains.bucket.SyncJob');
            actions = wait(job);

            testCase.verifyEqual(job.State, "finished");
            testCase.verifyEqual(actions.Status, ["done"; "done"]);
            testCase.verifyEqual(spy.Calls([1, end]), ["phaseStarted listing"; "syncFinished"]);
            testCase.verifyTrue(ismember("fileFinished 2 done", spy.Calls));
        end

        function testCancelKeepsTableOfWhatWasDone(testCase)
            writeFiles(testCase.Folder, "file" + (1:6) + ".txt");
            queueEmptyListingAndUrls(testCase.Client, 6);
            job = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Background=true, Uploader=@slowUploader, Client=testCase.Client);
            pause(0.8)

            cancel(job)
            actions = testCase.verifyWarning(@() wait(job), 'EBRAINS:Bucket:Sync:Cancelled');

            testCase.verifyEqual(job.State, "cancelled");
            testCase.verifyTrue(any(actions.Status == "done"));
            testCase.verifyTrue(any(actions.Status == "skipped"));
        end

        function testStopEndsStalledTransfer(testCase)
            writeFiles(testCase.Folder, "a.txt");
            queueEmptyListingAndUrls(testCase.Client, 1);
            job = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Background=true, Uploader=@stalledUploader, Client=testCase.Client);
            pause(0.5)

            startTime = tic;
            stop(job)
            testCase.verifyError(@() wait(job), 'EBRAINS:Bucket:Sync:Stopped');

            testCase.verifyLessThan(toc(startTime), 5);
            testCase.verifyEqual(job.State, "stopped");
            testCase.verifyEmpty(job.Actions);
        end

        function testErrorOnWorkerFailsJob(testCase)
            writeFiles(testCase.Folder, "a.txt");
            testCase.Client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', 2, 'bytes', 0));
            testCase.Client.addResponse('OK', struct('objects', struct( ...
                'name', {'x.txt'; 'y.txt'}, 'bytes', 1, 'last_modified', '', ...
                'hash', '', 'content_type', 'text/plain')));
            spy = ebrains.mocks.SpySyncProgressObserver();

            job = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Background=true, Delete=true, MaxDelete=1, ...
                ProgressObserver=spy, Client=testCase.Client);

            testCase.verifyError(@() wait(job), 'EBRAINS:Bucket:Sync:TooManyDeletions');
            testCase.verifyEqual(job.State, "failed");
            testCase.verifyEqual(spy.Calls(end), "syncFailed");
        end

        function testWorkerSyncObserverTakesCancelAndTokenMessages(testCase)
            progressQueue = parallel.pool.DataQueue;
            firstField = matlab.net.http.field.AuthorizationField("Authorization", "Bearer first");
            observer = ebrains.bucket.internal.WorkerSyncObserver(progressQueue, firstField);
            testCase.verifyEqual(observer.authorizationField(), firstField);
            testCase.verifyFalse(observer.isCancelRequested());

            renewedField = matlab.net.http.field.AuthorizationField("Authorization", "Bearer renewed");
            send(observer.ControlQueue, struct("Type", "authorization", "Field", renewedField))
            send(observer.ControlQueue, struct("Type", "cancel"))

            testCase.verifyEqual(observer.authorizationField(), renewedField);
            testCase.verifyTrue(observer.isCancelRequested());
        end

        function testWorkerClientSendsTokenFromSession(testCase)
            % runSyncOnWorker runs here instead of on a worker, so that
            % the client it changes can be inspected.
            queueEmptyListingAndUrls(testCase.Client, 0);
            queues = struct("Progress", parallel.pool.DataQueue, ...
                "Handshake", parallel.pool.PollableDataQueue);
            field = matlab.net.http.field.AuthorizationField("Authorization", "Bearer from-session");
            options = struct("Prefix", "", "Delete", false, "Comparison", "SizeAndTime", ...
                "Exclude", string.empty, "DryRun", false, "MaxDelete", Inf, ...
                "Verbose", true, "DisplayMode", "Window", "Client", testCase.Client, ...
                "Uploader", @acceptingUploader, "Downloader", @acceptingUploader);

            ebrains.bucket.internal.runSyncOnWorker("ToBucket", testCase.Folder, ...
                "my-bucket", options, queues, field);

            testCase.verifyEqual(testCase.Client.AuthorizationFcn(), field);
        end
    end
end

function writeFiles(folder, names)
    for name = names
        writelines("abc", fullfile(folder, name));
    end
end

function queueEmptyListingAndUrls(client, numUrls)
% queueEmptyListingAndUrls - Responses of an empty bucket and of numUrls upload URL requests
    client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', 0, 'bytes', 0));
    client.addResponse('OK', struct('objects', []));
    for k = 1:numUrls
        client.addResponse('OK', struct('url', sprintf('https://store.example.org/upload?sig=%d', k)));
    end
end

function [wasSuccess, response] = acceptingUploader(varargin)
    wasSuccess = true;
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK);
end

function [wasSuccess, response] = slowUploader(varargin)
% slowUploader - Uploader that takes half a second per file
    pause(0.5)
    [wasSuccess, response] = acceptingUploader();
end

function [wasSuccess, response] = stalledUploader(varargin) %#ok<STOUT>
% stalledUploader - Uploader that never returns, as a transfer whose connection has stalled
    pause(600)
end
