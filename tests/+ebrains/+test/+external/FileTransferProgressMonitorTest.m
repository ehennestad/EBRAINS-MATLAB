classdef FileTransferProgressMonitorTest < matlab.unittest.TestCase
    % FileTransferProgressMonitorTest - Tests for the bundled progress monitor
    %
    % Drives the monitor the way matlab.net.http does during a transfer,
    % by setting Direction and Value, so no request is needed. Max is
    % read-only on the base class; FileSizeBytes stands in for it.

    methods (Test)
        function testCommandWindowProgressSurvivesRepeatedUpdates(testCase)
            % From the second update on, the progress message arrives as
            % split parts. The release crashed when printing them.
            monitor = ebrains.external.filedownload.FileTransferProgressMonitor(...
                'DisplayMode', 'Command Window', 'UpdateInterval', 0.001);
            testCase.addTeardown(@() delete(monitor));
            monitor.Direction = matlab.net.http.MessageType.Response;
            monitor.FileSizeBytes = 1000;

            output = evalc(['pause(0.01); monitor.Value = uint64(100); ', ...
                'pause(0.01); monitor.Value = uint64(600); ', ...
                'pause(0.01); monitor.Value = uint64(1000); monitor.done();']);

            testCase.verifySubstring(output, 'Downloading File...');
            testCase.verifySubstring(output, 'Completed in');
        end

        function testDisplayModeSelectsCommandWindow(testCase)
            monitor = ebrains.external.filedownload.FileTransferProgressMonitor(...
                'DisplayMode', 'Command Window');
            testCase.addTeardown(@() delete(monitor));

            % These getters go through the static isWebBasedUIFigure method,
            % which the namespace copy calls through the instance.
            testCase.verifyTrue(monitor.UseCommandWindow);
            testCase.verifyFalse(monitor.UseWaitbarDialog);
            testCase.verifyFalse(monitor.UseUIProgressDialog);
        end
    end
end
