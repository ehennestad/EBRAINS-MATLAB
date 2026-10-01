classdef BucketLiveTest < matlab.unittest.TestCase
    % BucketLiveTest - Live checks of the ebrains.bucket functions
    %
    % Exercises listing, upload in one request and in parts, download,
    % size lookup, and delete against the real EBRAINS Data Proxy API,
    % using a bucket the authenticated account has write access to.
    % Tagged "LiveIntegration"; excluded from the default test run (see
    % tools/tasks/testToolbox.m) and run on a schedule by
    % .github/workflows/run-live-tests.yml.

    properties (Constant)
        % Bucket names are the collab id in lowercase, independent of the
        % collab's display title.
        BucketName = "eivihe-sandbox"
    end

    methods (Test, TestTags = {'LiveIntegration'})
        function testListBucketObjects(testCase)
            objects = ebrains.bucket.listBucketObjects(testCase.BucketName);
            testCase.verifyClass(objects, 'struct')
        end

        function testUploadDownloadDeleteRoundTrip(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "probe.txt");
            fileId = fopen(sourceFile, "w");
            fprintf(fileId, "EBRAINS-MATLAB live test %s\n", string(datetime("now", TimeZone="UTC")));
            fclose(fileId);
            sourceSizeBytes = dir(sourceFile).bytes;

            objectName = "live-test/probe-" + string(datetime("now", Format="yyyyMMdd-HHmmssSSS")) + ".txt";
            % A failed assertion between upload and the explicit delete
            % below must not leave the probe object in the bucket.
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, objectName));

            ebrains.bucket.uploadFile(testCase.BucketName, objectName, sourceFile);
            testCase.verifyEqual(ebrains.bucket.getFileSize(testCase.BucketName, objectName), sourceSizeBytes);

            targetFile = fullfile(folderFixture.Folder, "downloaded.txt");
            ebrains.bucket.downloadFile(testCase.BucketName, objectName, targetFile);
            testCase.verifyEqual(dir(targetFile).bytes, sourceSizeBytes);
            % The downloader's temporary file must not remain in the folder
            listing = dir(folderFixture.Folder);
            fileNames = string({listing(~[listing.isdir]).name});
            testCase.verifyEqual(sort(fileNames), ["downloaded.txt", "probe.txt"]);

            ebrains.bucket.deleteObject(testCase.BucketName, objectName);
            testCase.verifyError(...
                @() ebrains.bucket.getFileSize(testCase.BucketName, objectName), ...
                'EBRAINS:Bucket:ObjectNotFound');
        end

        function testMultipartUploadRoundTrip(testCase)
            % Three parts, the last one smaller than the others. The
            % threshold is lowered so that a file of a few MiB takes the
            % multipart path.
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            partSizeBytes = 5*2^20;
            fileSizeBytes = 2*partSizeBytes + 2^20;
            sourceFile = fullfile(folderFixture.Folder, "probe.bin");
            writePatternedBytes(sourceFile, fileSizeBytes);

            objectName = "live-test/multipart-" + string(datetime("now", Format="yyyyMMdd-HHmmssSSS")) + ".bin";
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, objectName));

            ebrains.bucket.uploadFile(testCase.BucketName, objectName, sourceFile, ...
                MultipartThreshold=2^20, PartSize=partSizeBytes, DisplayMode="Command Window");
            testCase.verifyFalse(isfile(sourceFile + ".multipart-upload.json"), ...
                'The manifest must be removed once the object is assembled.');
            testCase.verifyEqual(ebrains.bucket.getFileSize(testCase.BucketName, objectName), fileSizeBytes);

            targetFile = fullfile(folderFixture.Folder, "downloaded.bin");
            ebrains.bucket.downloadFile(testCase.BucketName, objectName, targetFile, DisplayMode="Command Window");
            testCase.verifyTrue(isequal(readBytes(targetFile), readBytes(sourceFile)), ...
                'The downloaded object differs from the source file.');

            ebrains.bucket.deleteObject(testCase.BucketName, objectName);
        end
    end
end

function deleteIfPresent(bucketName, objectName)
% deleteIfPresent - Best-effort cleanup of a probe object
    try
        ebrains.bucket.deleteObject(bucketName, objectName);
    catch
        % Already removed by the test itself, or the upload never reached
        % the bucket; either way there is nothing left to clean up.
    end
end

function writePatternedBytes(filePath, numBytes)
% writePatternedBytes - Write a file whose bytes repeat a pattern longer than a part
    fileId = fopen(filePath, "w");
    fwrite(fileId, uint8(mod(0:numBytes-1, 251)));
    fclose(fileId);
end

function bytes = readBytes(filePath)
% readBytes - The bytes of a file as a uint8 column
    fileId = fopen(filePath, "r");
    bytes = fread(fileId, Inf, "*uint8");
    fclose(fileId);
end
