classdef DownloadProgressTest < matlab.unittest.TestCase
    % DownloadProgressTest - Unit tests for the progress of a download of several files
    %
    % ebrains.bucket.app.internal.DownloadProgress writes to a
    % FakeProgressDialog, so the tests open no window and send no request.
    % The progress redraws on every report (UpdateInterval=0) and
    % estimates the time left from the start (MinimumEstimateSeconds=0),
    % unless a test is about one of the two.

    methods (Test)
        function testBarShowsBytesAcrossFiles(testCase)
            [progress, dialog] = makeProgress([100; 300]);

            progress.startFile("a.txt")
            progress.finishFile(true)
            progress.startFile("b.txt")
            progress.reportBytes(150)

            testCase.verifyEqual(dialog.Value, 250 / 400, AbsTol=1e-12);
            testCase.verifySubstring(dialog.Message, "Downloading file 2 of 2.");
            testCase.verifySubstring(dialog.Message, "250 B of 400 B downloaded.");
        end

        function testMessageHasALineForTheFileNumberTheNameAndTheBytes(testCase)
            dialog = ebrains.mocks.FakeProgressDialog([]);
            progress = ebrains.bucket.app.internal.DownloadProgress(dialog, [100; 300], ...
                UpdateInterval=0, MinimumEstimateSeconds=Inf);

            progress.startFile("sub/a.txt")
            progress.reportBytes(50)

            testCase.verifyEqual(splitlines(dialog.Message), ...
                ["Downloading file 1 of 2."; "sub/a.txt"; "50 B of 400 B downloaded."]);
        end

        function testTimeLeftSharesTheLineOfTheBytes(testCase)
            [progress, dialog] = makeProgress([100; 300]);

            progress.startFile("a.txt")
            progress.finishFile(true)

            lines = splitlines(dialog.Message);
            testCase.assertNumElements(lines, 3);
            testCase.verifyTrue(startsWith(lines(3), "100 B of 400 B downloaded. About "));
            testCase.verifyTrue(endsWith(lines(3), " left."));
        end

        function testLongNameKeepsItsEnd(testCase)
            [progress, dialog] = makeProgress(100);
            name = string(repmat('folder/', 1, 20)) + "chunk.bin";

            progress.startFile(name)

            lines = splitlines(dialog.Message);
            testCase.verifyEqual(strlength(lines(2)), 60);
            testCase.verifyTrue(startsWith(lines(2), "..."));
            testCase.verifyTrue(endsWith(lines(2), "folder/chunk.bin"));
        end

        function testFileCountHasThousandsSeparators(testCase)
            [progress, dialog] = makeProgress(ones(8312, 1));

            progress.startFile("0.0.0")

            testCase.verifySubstring(dialog.Message, "Downloading file 1 of 8,312.");
        end

        function testFailedFileIsTakenOutOfTheTotal(testCase)
            [progress, dialog] = makeProgress([100; 300]);

            progress.startFile("a.txt")
            progress.finishFile(false)
            progress.startFile("b.txt")
            progress.reportBytes(150)

            testCase.verifyEqual(dialog.Value, 0.5, AbsTol=1e-12);
            testCase.verifySubstring(dialog.Message, "150 B of 300 B downloaded.");
        end

        function testBarIsFullWhenEveryOtherFileIsDownloaded(testCase)
            [progress, dialog] = makeProgress([100; 300]);

            progress.startFile("a.txt")
            progress.finishFile(false)
            progress.startFile("b.txt")
            progress.finishFile(true)

            testCase.verifyEqual(dialog.Value, 1);
        end

        function testUnknownSizeShowsFilesFinished(testCase)
            [progress, dialog] = makeProgress([NaN; 300]);

            progress.startFile("a.txt")
            progress.reportBytes(2048)
            valueDuringFirstFile = dialog.Value;
            progress.finishFile(true)
            progress.startFile("b.txt")

            testCase.verifyEqual(valueDuringFirstFile, 0);
            testCase.verifyEqual(dialog.Value, 0.5);
            lines = splitlines(dialog.Message);
            testCase.verifyEqual(lines(1), "Downloading file 2 of 2.");
            testCase.verifyTrue(startsWith(lines(3), "2.0 KB downloaded."));
        end

        function testBytesOfAFileWithoutReportsCountWhenItIsDownloaded(testCase)
            [progress, dialog] = makeProgress([100; 300]);

            progress.startFile("a.txt")
            progress.finishFile(true)

            testCase.verifyEqual(progress.DownloadedBytes, 100);
            testCase.verifyEqual(dialog.Value, 0.25, AbsTol=1e-12);
        end

        function testEmptyFilesAreMeasuredByCount(testCase)
            [progress, dialog] = makeProgress([0; 0]);

            progress.startFile("a.txt")
            progress.finishFile(true)

            testCase.verifyEqual(dialog.Value, 0.5);
        end

        function testTimeLeftIsShownOnceThereIsARate(testCase)
            [progress, dialog] = makeProgress([100; 300]);

            progress.startFile("a.txt")
            messageBeforeAnyByte = dialog.Message;
            progress.finishFile(true)

            testCase.verifyFalse(contains(messageBeforeAnyByte, "left."));
            testCase.verifySubstring(dialog.Message, "left.");
        end

        function testTimeLeftWaitsForMinimumEstimateSeconds(testCase)
            dialog = ebrains.mocks.FakeProgressDialog([]);
            progress = ebrains.bucket.app.internal.DownloadProgress(dialog, [100; 300], ...
                UpdateInterval=0, MinimumEstimateSeconds=Inf);

            progress.startFile("a.txt")
            progress.finishFile(true)

            testCase.verifyFalse(contains(dialog.Message, "left."));
        end

        function testReportWithinUpdateIntervalIsNotDrawn(testCase)
            dialog = ebrains.mocks.FakeProgressDialog([]);
            progress = ebrains.bucket.app.internal.DownloadProgress(dialog, [100; 300], UpdateInterval=Inf);

            progress.startFile("a.txt")
            progress.reportBytes(50)

            testCase.verifyEqual(dialog.Value, 0, "The first report is drawn, the second is within the interval.");
            testCase.verifyEqual(progress.CurrentBytes, 50, "A report that is not drawn is kept.");
        end

        function testCancelIsReported(testCase)
            [progress, dialog] = makeProgress(100);

            wasRequestedBefore = progress.isCancelRequested();
            dialog.CancelRequested = true;

            testCase.verifyFalse(wasRequestedBefore);
            testCase.verifyTrue(progress.isCancelRequested());
        end

        function testDeletedDialogCountsAsCancel(testCase)
            [progress, dialog] = makeProgress(100);
            progress.startFile("a.txt")

            delete(dialog)

            testCase.verifyTrue(progress.isCancelRequested());
            testCase.verifyWarningFree(@() progress.reportBytes(50));
        end
    end
end

function [progress, dialog] = makeProgress(fileBytes)
% makeProgress - Progress of files of the given sizes that redraws on every report and estimates from the start
    dialog = ebrains.mocks.FakeProgressDialog([]);
    progress = ebrains.bucket.app.internal.DownloadProgress(dialog, fileBytes, ...
        UpdateInterval=0, MinimumEstimateSeconds=0);
end
