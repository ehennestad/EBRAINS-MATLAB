classdef WebprogressPackageTest < matlab.unittest.TestCase
    % WebprogressPackageTest - Smoke tests for the vendored webprogress package
    %
    % tools/tasks/updateVendoredPackages copies the package and renames its
    % namespace from webprogress to ebrains.external.webprogress. The
    % behaviour of the package is tested in its own repository. These tests
    % call each class and function of the copy by its new name, and each
    % private function that runs before a request is sent. A call fails to
    % resolve if the copy is incomplete or a name was missed. No test sends
    % a request, so the lines of download and upload that run during a
    % transfer are not reached. BucketLiveTest transfers a file through both.

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

        function testDownloadResolvesCallbackFunctions(testCase)
            % ProgressFcn is checked by a validator in the private folder.
            % CancelRequestedFcn is called through another private function
            % before a request is sent.
            testCase.verifyError(...
                @() ebrains.external.webprogress.download(...
                    'file.txt', 'https://example.org/file.txt', 'ProgressFcn', 42), ...
                'webprogress:validators:InvalidFunctionHandle');
            testCase.verifyError(...
                @() ebrains.external.webprogress.download(...
                    'file.txt', 'https://example.org/file.txt', 'CancelRequestedFcn', @() true), ...
                'webprogress:download:Cancelled');
        end

        function testMultipartMonitorResolvesItsSuperclass(testCase)
            % The monitor of a multipart upload derives from the renamed
            % FileTransferProgressMonitor.
            totalBytes = 100;
            monitor = ebrains.external.webprogress.MultipartProgressMonitor(totalBytes, ...
                'DisplayMode', 'Command Window');
            testCase.addTeardown(@() delete(monitor));

            testCase.verifyTrue(isa(monitor, 'ebrains.external.webprogress.FileTransferProgressMonitor'));
            testCase.verifyEqual(monitor.FileSizeBytes, totalBytes);
            testCase.verifyEqual(monitor.CompletedBytes, 0);
        end

        function testUploadResolvesTheRangeProvider(testCase)
            % A byte range is sent through the provider in the internal
            % sub-namespace. upload checks the range against the file
            % before it sends a request.
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "file.bin");
            writelines("content", sourceFile);
            offset = 1;
            numBytes = 2;
            offsetPastEnd = 1000;

            provider = ebrains.external.webprogress.internal.FileRangeProvider(sourceFile, offset, numBytes);

            testCase.verifyEqual(provider.NumBytes, numBytes);
            testCase.verifyError(...
                @() ebrains.external.webprogress.upload(sourceFile, 'https://example.org/part', ...
                    'Offset', offsetPastEnd, 'NumBytes', numBytes), ...
                'webprogress:upload:RangeOutsideFile');
        end

        function testResumableConsumerResolvesItsSuperclass(testCase)
            % A resumable download writes the body through the consumer in
            % the internal sub-namespace. No file is created before a
            % response arrives.
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            partialFile = fullfile(folderFixture.Folder, "file.bin.part");
            stateFile = partialFile + ".json";
            offset = 0;

            consumer = ebrains.external.webprogress.internal.ResumableFileConsumer( ...
                partialFile, stateFile, offset, "", nan);

            testCase.verifyTrue(isa(consumer, 'matlab.net.http.io.FileConsumer'));
            testCase.verifyEqual(consumer.RequestedOffset, offset);
        end

        function testResponseHeaderFunctionsResolve(testCase)
            % download reads the header of a response with four functions
            % in the internal sub-namespace.
            entityTag = '"abc"';
            header = [ ...
                matlab.net.http.HeaderField('Content-Length', '50'), ...
                matlab.net.http.HeaderField('ETag', entityTag), ...
                matlab.net.http.HeaderField('Content-Range', 'bytes 50-99/100')];
            response = matlab.net.http.ResponseMessage([], header);

            [firstByte, lastByte, completeLength] = ...
                ebrains.external.webprogress.internal.parseContentRange(response);

            testCase.verifyEqual([firstByte, lastByte, completeLength], [50, 99, 100]);
            testCase.verifyEqual(ebrains.external.webprogress.internal.getDeclaredLength(response), 50);
            testCase.verifyEqual(ebrains.external.webprogress.internal.getStrongETag(response), string(entityTag));
            testCase.verifyTrue(ebrains.external.webprogress.internal.hasIdentityEncoding(response));
        end
    end
end
