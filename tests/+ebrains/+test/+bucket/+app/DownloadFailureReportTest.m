classdef DownloadFailureReportTest < matlab.unittest.TestCase
    % DownloadFailureReportTest - Unit tests for the text of the alert about failed downloads
    %
    % ebrains.bucket.app.internal.downloadFailureReport builds the text
    % from paths and error messages. It needs no user interface and sends
    % no request.

    methods (Test)
        function testSeveralFailuresGiveOneText(testCase)
            message = ebrains.bucket.app.internal.downloadFailureReport( ...
                ["a.txt"; "b.txt"], ["NotFound: a"; "NotFound: b"], 2);

            testCase.verifySize(message, [1 1]);
        end

        function testSharedReasonIsStatedOnce(testCase)
            paths = "folder/file" + (1:16)' + ".txt";
            reason = "Unauthorized: This request requires authentication.";

            message = ebrains.bucket.app.internal.downloadFailureReport(paths, repmat(reason, 16, 1), 16);

            expected = join([ ...
                "16 of 16 files could not be downloaded."
                ""
                reason
                "- folder/file1.txt"
                "- folder/file2.txt"
                "- folder/file3.txt"
                "- and 13 more"], newline, 1);
            testCase.verifyEqual(message, expected);
        end

        function testEachReasonListsItsOwnFiles(testCase)
            paths = ["a.txt"; "b.txt"; "c.txt"];
            reasons = ["NotFound: Object not found"; "The download has the wrong size."; ...
                "NotFound: Object not found"];

            message = ebrains.bucket.app.internal.downloadFailureReport(paths, reasons, 5);

            expected = join([ ...
                "3 of 5 files could not be downloaded."
                ""
                "NotFound: Object not found"
                "- a.txt"
                "- c.txt"
                ""
                "The download has the wrong size."
                "- b.txt"], newline, 1);
            testCase.verifyEqual(message, expected);
        end

        function testFilesOfReasonsPastTheThirdAreCounted(testCase)
            paths = "file" + (1:5)' + ".txt";
            reasons = "Reason " + [1; 2; 3; 4; 5];

            message = ebrains.bucket.app.internal.downloadFailureReport(paths, reasons, 5);

            testCase.verifySubstring(message, "Reason 3" + newline + "- file3.txt");
            testCase.verifyFalse(contains(message, "Reason 4"));
            testCase.verifyTrue(endsWith(message, "2 more files could not be downloaded for other reasons."));
        end

        function testOneFilePastTheThirdReasonIsCountedInTheSingular(testCase)
            paths = "file" + (1:4)' + ".txt";
            reasons = "Reason " + [1; 2; 3; 4];

            message = ebrains.bucket.app.internal.downloadFailureReport(paths, reasons, 4);

            testCase.verifyTrue(endsWith(message, "1 more file could not be downloaded for another reason."));
        end

        function testBatchOfOneFileNamesTheFile(testCase)
            message = ebrains.bucket.app.internal.downloadFailureReport( ...
                "sub/a.txt", "NotFound: Object not found", 1);

            expected = """sub/a.txt"" could not be downloaded." + newline + newline + "NotFound: Object not found";
            testCase.verifyEqual(message, expected);
        end

        function testRowVectorsAreAccepted(testCase)
            message = ebrains.bucket.app.internal.downloadFailureReport( ...
                ["a.txt", "b.txt"], ["Reason", "Reason"], 3);

            expected = join([ ...
                "2 of 3 files could not be downloaded."
                ""
                "Reason"
                "- a.txt"
                "- b.txt"], newline, 1);
            testCase.verifyEqual(message, expected);
        end
    end
end
