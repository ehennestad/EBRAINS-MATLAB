classdef UploadFileTest < matlab.unittest.TestCase
    % UploadFileTest - Tests for the bundled file uploader
    %
    % The uploader is part of the filedownload library placed in the
    % ebrains namespace. These tests cover what the namespace changes:
    % the private validators must resolve from the package folder, and
    % every argument default must be valid on its own.

    methods (Test)
        function testInvalidDisplayModeIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.external.filedownload.uploadFile(...
                    'file.txt', 'https://example.org/file.txt', 'DisplayMode', 'Nowhere'), ...
                'MATLAB:validators:mustBeMember');
        end

        function testMissingLocalFileIsReportedAfterValidation(testCase)
            % Reaching the file error proves that every argument default
            % validated, which the release's [] for RequestMessage did not.
            testCase.verifyError(...
                @() ebrains.external.filedownload.uploadFile(...
                    '/nonexistent/folder/missing.bin', 'https://example.org/file.txt'), ...
                'MATLAB:http:FileNotFound');
        end

        function testInvalidFigureIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.external.filedownload.uploadFile(...
                    'file.txt', 'https://example.org/file.txt', 'Figure', 42), ...
                'filedownload:invalidFigure');
        end
    end
end
