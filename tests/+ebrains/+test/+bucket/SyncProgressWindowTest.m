classdef SyncProgressWindowTest < matlab.uitest.TestCase
    % SyncProgressWindowTest - Tests of ebrains.bucket.internal.SyncProgressWindow
    %
    % Opens the real window, reports a sync to it as runSync does, and
    % presses its buttons. Tagged "Graphical": it needs a display, so the
    % CI test task (tools/tasks/testToolbox.m) leaves it out, and it is
    % meant to be run locally.

    properties (Constant)
        WindowName = "EBRAINS bucket sync"
    end

    methods (TestMethodTeardown)
        function closeWindows(testCase)
            delete(findall(groot, 'Type', 'figure', 'Name', testCase.WindowName))
        end
    end

    methods (Test, TestTags = {'Graphical'})
        function testPlanShowsFilesWithActionOnly(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");

            window.planReady(makeActions())

            data = window.FileTable.Data;
            testCase.verifyEqual(data.Path, ["a.txt"; "c.txt"]);
            testCase.verifyEqual(data.Status, ["queued"; "queued"]);
            testCase.verifySubstring(char(data.Progress(1)), 'width:0%');
            testCase.verifyEqual(data.Progress(2), "", 'A deletion has no bar.');
            testCase.verifyEqual(window.SummaryLabel.Text, ...
                '1 file(s) to copy (100 B), 1 to delete, 1 unchanged.');
        end

        function testTransferUpdatesRowAndTotals(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");
            window.planReady(makeActions())
            window.phaseStarted("copying")

            window.fileStarted(1)
            testCase.verifyEqual(window.FileTable.Data.Status(1), "uploading...");
            window.bytesTransferred(1, 40, 100)

            testCase.verifyEqual(window.FileTable.Data.Status(1), "40%");
            testCase.verifySubstring(char(window.FileTable.Data.Progress(1)), 'width:40%');
            testCase.verifySubstring(window.SummaryLabel.Text, '0/1 files, 40 B/100 B');
        end

        function testUnknownTransferSizeUsesSizeFromPlan(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");
            window.planReady(makeActions())

            window.bytesTransferred(1, 25, NaN)

            testCase.verifyEqual(window.FileTable.Data.Status(1), "25%");
        end

        function testFinishedSyncShowsResultAndClose(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");
            actions = makeActions();
            window.planReady(actions)
            window.fileStarted(1)
            window.fileFinished(1, "done", "")
            actions.Status = ["done"; ""; "skipped"];
            actions.Message(3) = "Not deleted, since the sync was cancelled.";

            window.syncFinished(actions)

            testCase.verifyEqual(window.FileTable.Data.Status, ["done"; "skipped"]);
            testCase.verifySubstring(char(window.FileTable.Data.Progress(1)), 'width:100%');
            testCase.verifyEqual(window.SummaryLabel.Text, ...
                'Done: 1 copied, 0 deleted, 0 failed, 1 cancelled or skipped.');
            testCase.verifyEqual(window.CancelButton.Text, 'Close');
        end

        function testFailedFileShowsItsMessage(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");
            window.planReady(makeActions())
            window.fileStarted(1)

            window.fileFinished(1, "failed", "403 Forbidden")

            testCase.verifyEqual(window.FileTable.Data.Status(1), "failed: 403 Forbidden");
        end

        function testCancelButtonRequestsCancel(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");
            window.planReady(makeActions())
            testCase.verifyFalse(window.isCancelRequested());

            testCase.press(window.CancelButton)

            testCase.verifyTrue(window.isCancelRequested());
            testCase.verifyEqual(window.CancelButton.Enable, matlab.lang.OnOffSwitchState.off);
        end

        function testClosingRunningSyncCancelsInsteadOfClosing(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");

            close(window.Figure)

            testCase.verifyTrue(isvalid(window.Figure));
            testCase.verifyTrue(window.isCancelRequested());
        end

        function testCloseButtonOfFinishedSyncClosesWindow(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");
            actions = makeActions();
            window.planReady(actions)
            window.syncFinished(actions)

            testCase.press(window.CancelButton)

            testCase.verifyFalse(isvalid(window.Figure));
        end

        function testFailedSyncShowsError(testCase)
            window = ebrains.bucket.internal.SyncProgressWindow("Syncing.");

            window.syncFailed(MException("Test:Failure", "Listing failed."))

            testCase.verifyEqual(window.SummaryLabel.Text, ...
                'The sync stopped with an error: Listing failed.');
            testCase.verifyEqual(window.CancelButton.Text, 'Close');
        end

        function testSyncToBucketInWindowCanBeCancelled(testCase)
            % The uploader presses Cancel while the first file is sent,
            % as a user would. The second file is then skipped.
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            writelines("abc", fullfile(folder, "a.txt"));
            writelines("abc", fullfile(folder, "b.txt"));
            client = ebrains.mocks.MockBucketsClient();
            client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', 0, 'bytes', 0));
            client.addResponse('OK', struct('objects', []));
            client.addResponse('OK', struct('url', 'https://store.example.org/upload?sig=1'));
            uploader = @(varargin) pressCancelAndAccept(testCase);

            actions = testCase.verifyWarning(@() ebrains.bucket.syncToBucket( ...
                folder, "my-bucket", DisplayMode="Window", Uploader=uploader, ...
                Client=client, Verbose=false), 'EBRAINS:Bucket:Sync:Cancelled');

            testCase.verifyEqual(actions.Status, ["done"; "skipped"]);
            window = findall(groot, 'Type', 'figure', 'Name', testCase.WindowName);
            testCase.assertNumElements(window, 1);
            closeButton = findall(window, 'Type', 'uibutton');
            testCase.verifyEqual(closeButton.Text, 'Close');
        end

        function testBackgroundSyncInWindowCanBeCancelled(testCase)
            % The Cancel button of the window reaches the worker through
            % the job, which ends with the table of what was done. press
            % takes over a second, so the sync is made long enough to
            % still run when it lands.
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            for name = "file" + (1:12) + ".txt"
                writelines("abc", fullfile(folder, name));
            end
            client = ebrains.mocks.MockBucketsClient();
            client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', 0, 'bytes', 0));
            client.addResponse('OK', struct('objects', []));
            for k = 1:12
                client.addResponse('OK', struct('url', 'https://store.example.org/upload'));
            end

            job = ebrains.bucket.syncToBucket(folder, "my-bucket", DisplayMode="Window", ...
                Background=true, Uploader=@slowUploader, Client=client);
            pause(0.8)
            window = findall(groot, 'Type', 'figure', 'Name', testCase.WindowName);
            % press processes the event queue, so the job can end, and
            % warn, before wait is called.
            function actions = pressCancelAndWait()
                testCase.press(findall(window, 'Type', 'uibutton'))
                actions = wait(job);
            end
            actions = testCase.verifyWarning(@pressCancelAndWait, 'EBRAINS:Bucket:Sync:Cancelled');

            testCase.verifyEqual(job.State, "cancelled");
            testCase.verifyTrue(any(actions.Status == "skipped"));
            testCase.verifyEqual(findall(window, 'Type', 'uibutton').Text, 'Close');
        end
    end
end

function [wasSuccess, response] = slowUploader(varargin)
% slowUploader - Uploader that takes half a second per file
    pause(0.5)
    wasSuccess = true;
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK);
end

function actions = makeActions()
% makeActions - Plan with a file to upload, an unchanged file and a file to delete
    actions = table(["a.txt"; "b.txt"; "c.txt"], ["upload"; "none"; "delete"], ...
        ["new"; "unchanged"; "extraneous"], [100; 5; 7], ["";"";""], ["";"";""], ...
        VariableNames=["Path", "Action", "Reason", "Bytes", "Status", "Message"]);
end

function [wasSuccess, response] = pressCancelAndAccept(testCase)
% pressCancelAndAccept - Uploader that presses Cancel in the sync window and accepts the file
    window = findall(groot, 'Type', 'figure', 'Name', ebrains.test.bucket.SyncProgressWindowTest.WindowName);
    cancelButton = findall(window, 'Type', 'uibutton');
    testCase.press(cancelButton)
    wasSuccess = true;
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK);
end
