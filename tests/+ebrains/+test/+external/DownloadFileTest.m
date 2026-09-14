classdef DownloadFileTest < matlab.unittest.TestCase
    % DownloadFileTest - Tests for the bundled file downloader
    %
    % The downloader is a copy of the filedownload library placed in the
    % ebrains namespace. These tests cover what the namespace changes: the
    % private validators must resolve from the package folder.

    methods (Test)
        function testInvalidDisplayModeIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.external.filedownload.downloadFile(...
                    'file.txt', 'https://example.org/file.txt', 'DisplayMode', 'Nowhere'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testInvalidFigureIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.external.filedownload.downloadFile(...
                    'file.txt', 'https://example.org/file.txt', 'Figure', 42), ...
                'filedownload:invalidFigure');
        end
    end
end
