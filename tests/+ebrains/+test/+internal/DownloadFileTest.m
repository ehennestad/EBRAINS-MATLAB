classdef DownloadFileTest < matlab.unittest.TestCase
    % DownloadFileTest - Tests for the bundled file downloader
    %
    % The downloader is a copy of the filedownload library placed in the
    % ebrains namespace. These tests cover what the namespace changes: the
    % private validators must resolve from the package folder, and the
    % progress monitor must reach its own static methods.

    methods (Test)
        function testInvalidDisplayModeIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.internal.extern.fex.filedownload.downloadFile(...
                    'file.txt', 'https://example.org/file.txt', 'DisplayMode', 'Nowhere'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testInvalidFigureIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.internal.extern.fex.filedownload.downloadFile(...
                    'file.txt', 'https://example.org/file.txt', 'Figure', 42), ...
                'filedownload:invalidFigure');
        end

        function testProgressMonitorResolvesDisplayMode(testCase)
            monitor = ebrains.internal.extern.fex.filedownload.FileTransferProgressMonitor(...
                'DisplayMode', 'Command Window');
            testCase.addTeardown(@() delete(monitor));

            % The display getters call the static isWebBasedUIFigure method.
            testCase.verifyTrue(monitor.UseCommandWindow);
            testCase.verifyFalse(monitor.UseWaitbarDialog);
            testCase.verifyFalse(monitor.UseUIProgressDialog);
        end
    end
end
