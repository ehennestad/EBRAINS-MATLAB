classdef WebprogressPackageTest < matlab.unittest.TestCase
    % WebprogressPackageTest - Smoke tests for the vendored webprogress package
    %
    % tools/tasks/updateVendoredPackages copies the package and renames its
    % namespace from webprogress to ebrains.external.webprogress. The
    % behaviour of the package is tested in its own repository. These tests
    % call each name that the renaming rewrites and each private function,
    % which fail to resolve if the copy is incomplete or a name was missed.
    % The one rewritten name they do not reach is the monitor that download
    % and upload create during a transfer, which BucketLiveTest covers.

    methods (Test)
        function testDownloadResolvesPrivateValidators(testCase)
            % Each validator is a function in the private folder of the
            % package. The error identifiers keep the webprogress name.
            testCase.verifyError(...
                @() ebrains.external.webprogress.download(...
                    'file.txt', 'not a url'), ...
                'webprogress:validators:InvalidUrl');
            testCase.verifyError(...
                @() ebrains.external.webprogress.download(...
                    'file.txt', 'https://example.org/file.txt', 'DisplayMode', 'Nowhere'), ...
                'MATLAB:validators:mustBeMember');
            testCase.verifyError(...
                @() ebrains.external.webprogress.download(...
                    'file.txt', 'https://example.org/file.txt', 'Figure', 42), ...
                'webprogress:validators:InvalidFigure');
        end

        function testUploadResolvesPrivateValidators(testCase)
            testCase.verifyError(...
                @() ebrains.external.webprogress.upload(...
                    'file.txt', 'https://example.org/file.txt', 'Figure', 42), ...
                'webprogress:validators:InvalidFigure');
        end

        function testMonitorResolvesStaticMethodInDisplayMode(testCase)
            % In the dialog box mode the two properties are computed with
            % the static method isWebBasedUIFigure, which the monitor calls
            % by its qualified name. No dialog opens before a transfer.
            monitor = ebrains.external.webprogress.FileTransferProgressMonitor(...
                'DisplayMode', 'Dialog Box');
            testCase.addTeardown(@() delete(monitor));

            testCase.verifyTrue(monitor.UseWaitbarDialog);
            testCase.verifyFalse(monitor.UseUIProgressDialog);
        end

        function testMonitorResolvesStaticMethodInTimeEstimate(testCase)
            % The estimate is formatted by the static method
            % formatTimeAsString, called by its qualified name.
            elapsedTime = minutes(1);
            percentTransferred = 25;

            estimate = ebrains.external.webprogress.FileTransferProgressMonitor.formatRemainingTimeEstimate( ...
                elapsedTime, percentTransferred);

            testCase.verifyEqual(estimate, 'Estimated time remaining: 3 minutes...');
        end

        function testMultipartMonitorResolvesItsSuperclass(testCase)
            % The monitor of a multipart upload derives from the renamed
            % FileTransferProgressMonitor.
            monitor = ebrains.external.webprogress.MultipartProgressMonitor(100, ...
                'DisplayMode', 'Command Window');
            testCase.addTeardown(@() delete(monitor));

            testCase.verifyTrue(isa(monitor, 'ebrains.external.webprogress.FileTransferProgressMonitor'));
            testCase.verifyEqual(monitor.TotalBytes, 100);
            testCase.verifyEqual(monitor.CompletedBytes, 0);
        end

        function testUploadResolvesTheRangeProvider(testCase)
            % A byte range is sent through the provider in the internal
            % sub-namespace, which upload names by its qualified name. The
            % range check comes first, so no request is sent.
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "file.bin");
            writelines("content", sourceFile);

            provider = ebrains.external.webprogress.internal.FileRangeProvider(sourceFile, 1, 2);
            testCase.verifyEqual(provider.NumBytes, 2);
            testCase.verifyError(...
                @() ebrains.external.webprogress.upload(sourceFile, 'https://example.org/part', ...
                    'Offset', 1000, 'NumBytes', 1), ...
                'webprogress:upload:RangeOutsideFile');
        end
    end
end
