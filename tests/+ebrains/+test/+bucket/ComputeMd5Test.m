classdef (TestTags = {'PlatformSpecific'}) ComputeMd5Test < matlab.unittest.TestCase
    % ComputeMd5Test - Tests of ebrains.bucket.internal.computeMd5
    %
    % computeMd5 runs the MD5 tool of the operating system, whose name and
    % output differ between Linux, Windows and macOS. Tagged
    % "PlatformSpecific", so the "Test on all platforms" workflow runs it
    % on each of them. The expected checksums were computed with Python's
    % hashlib.

    properties
        Folder string
    end

    methods (TestMethodSetup)
        function createFolder(testCase)
            testCase.Folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
        end
    end

    methods (Test)
        function testKnownContent(testCase)
            filePath = writeBytes(fullfile(testCase.Folder, "abc.txt"), uint8('abc'));

            testCase.verifyEqual(ebrains.bucket.internal.computeMd5(filePath), ...
                "900150983cd24fb0d6963f7d28e17f72");
        end

        function testEmptyFile(testCase)
            filePath = writeBytes(fullfile(testCase.Folder, "empty.txt"), uint8([]));

            testCase.verifyEqual(ebrains.bucket.internal.computeMd5(filePath), ...
                "d41d8cd98f00b204e9800998ecf8427e");
        end

        function testBinaryContentOfOneMebibyte(testCase)
            content = repmat(uint8(0:255), 1, 4096);
            filePath = writeBytes(fullfile(testCase.Folder, "data.bin"), content);

            testCase.verifyEqual(ebrains.bucket.internal.computeMd5(filePath), ...
                "c35cc7d8d91728a0cb052831bc4ef372");
        end

        function testPathWithShellCharacters(testCase)
            % A space, a quote and a dollar sign would split, end or
            % expand an unquoted path in a shell.
            folder = fullfile(testCase.Folder, "with space's $HOME");
            mkdir(folder)
            filePath = writeBytes(fullfile(folder, "a b.txt"), uint8('abc'));

            testCase.verifyEqual(ebrains.bucket.internal.computeMd5(filePath), ...
                "900150983cd24fb0d6963f7d28e17f72");
        end

        function testFileNamedLikeAChecksum(testCase)
            % certutil prints the file name before the checksum, so a name
            % of 32 hexadecimal characters must not be read as the result.
            filePath = writeBytes(fullfile(testCase.Folder, ...
                "0123456789abcdef0123456789abcdef.txt"), uint8('abc'));

            testCase.verifyEqual(ebrains.bucket.internal.computeMd5(filePath), ...
                "900150983cd24fb0d6963f7d28e17f72");
        end

        function testOnBackgroundWorker(testCase)
            % A background sync computes checksums on a thread-based
            % worker, where Java and some other functions are not available.
            filePath = writeBytes(fullfile(testCase.Folder, "abc.txt"), uint8('abc'));

            future = parfeval(backgroundPool, @ebrains.bucket.internal.computeMd5, 1, filePath);

            testCase.verifyEqual(fetchOutputs(future), "900150983cd24fb0d6963f7d28e17f72");
        end

        function testMissingFileIsRejected(testCase)
            testCase.verifyError(@() ebrains.bucket.internal.computeMd5( ...
                fullfile(testCase.Folder, "missing.txt")), 'MATLAB:validators:mustBeFile');
        end
    end
end

function filePath = writeBytes(filePath, content)
% writeBytes - Write bytes to a file and return its path
    fileId = fopen(filePath, "w");
    fwrite(fileId, content, "uint8");
    fclose(fileId);
end
