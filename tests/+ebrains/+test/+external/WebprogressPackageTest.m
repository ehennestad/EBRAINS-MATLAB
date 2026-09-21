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
    end
end
