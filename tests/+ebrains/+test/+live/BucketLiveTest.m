classdef BucketLiveTest < matlab.unittest.TestCase
    % BucketLiveTest - Live checks of the ebrains.bucket functions
    %
    % Exercises listing, upload in one request and in parts, download,
    % size lookup, copy, and delete against the real EBRAINS Data Proxy API,
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

        function testCopyObjectLeavesTheSourceAndWritesAnEqualCopy(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "probe.txt");
            fileId = fopen(sourceFile, "w");
            fprintf(fileId, "EBRAINS-MATLAB live copy test %s\n", string(datetime("now", TimeZone="UTC")));
            fclose(fileId);
            sourceSizeBytes = dir(sourceFile).bytes;

            stamp = string(datetime("now", Format="yyyyMMdd-HHmmssSSS"));
            objectName = "live-test/copy-source-" + stamp + ".txt";
            copyName = "live-test/copied/copy-target-" + stamp + ".txt";
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, objectName));
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, copyName));

            ebrains.bucket.uploadFile(testCase.BucketName, objectName, sourceFile);
            ebrains.bucket.copyObject(testCase.BucketName, objectName, copyName);

            % The proxy completes the copy in the background after it has
            % answered, so the copy is awaited rather than expected at once.
            testCase.assertTrue(waitForObject(testCase.BucketName, copyName), ...
                'The copy did not appear in the bucket within the wait.');
            testCase.verifyEqual(ebrains.bucket.getFileSize(testCase.BucketName, copyName), sourceSizeBytes, ...
                'The copy must have the size of the source.');
            testCase.verifyEqual(ebrains.bucket.getFileSize(testCase.BucketName, objectName), sourceSizeBytes, ...
                'The source must still be in the bucket after the copy.');

            targetFile = fullfile(folderFixture.Folder, "downloaded.txt");
            ebrains.bucket.downloadFile(testCase.BucketName, copyName, targetFile);
            testCase.verifyTrue(isequal(readBytes(targetFile), readBytes(sourceFile)), ...
                'The downloaded copy differs from the source file.');
        end

        function testCopyObjectCopiesAFolderWithEverythingInIt(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "probe.txt");
            writelines("EBRAINS-MATLAB live folder copy test " + string(datetime("now", TimeZone="UTC")), sourceFile);

            stamp = string(datetime("now", Format="yyyyMMdd-HHmmssSSS"));
            sourceFolder = "live-test/copy-folder-" + stamp + "/";
            targetFolder = "live-test/copy-folder-" + stamp + "-copy/";
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, sourceFolder));
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, targetFolder));

            ebrains.bucket.uploadFile(testCase.BucketName, sourceFolder + "a.txt", sourceFile);
            ebrains.bucket.uploadFile(testCase.BucketName, sourceFolder + "sub/b.txt", sourceFile);

            ebrains.bucket.copyObject(testCase.BucketName, sourceFolder, targetFolder);

            % The copy completes in the background; the nested object is
            % the last to look for, since the copy covers the whole folder.
            testCase.assertTrue(waitForObject(testCase.BucketName, targetFolder + "sub/b.txt"), ...
                'The nested copy did not appear in the bucket within the wait.');
            testCase.assertTrue(waitForObject(testCase.BucketName, targetFolder + "a.txt"));
            testCase.verifyEqual(ebrains.bucket.getFileSize(testCase.BucketName, targetFolder + "sub/b.txt"), ...
                dir(sourceFile).bytes);
            testCase.verifyTrue(ebrains.bucket.internal.hasObject( ...
                ebrains.bucket.api.BucketsClient(), testCase.BucketName, sourceFolder), ...
                'The source folder must still be in the bucket after the copy.');
        end

        function testRenameObjectMovesTheObjectAndRefusesATakenTarget(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "probe.txt");
            fileId = fopen(sourceFile, "w");
            fprintf(fileId, "EBRAINS-MATLAB live rename test %s\n", string(datetime("now", TimeZone="UTC")));
            fclose(fileId);
            sourceSizeBytes = dir(sourceFile).bytes;

            stamp = string(datetime("now", Format="yyyyMMdd-HHmmssSSS"));
            objectName = "live-test/rename-source-" + stamp + ".txt";
            takenName = "live-test/rename-taken-" + stamp + ".txt";
            newName = "live-test/renamed/rename-target-" + stamp + ".txt";
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, objectName));
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, takenName));
            testCase.addTeardown(@() deleteIfPresent(testCase.BucketName, newName));

            ebrains.bucket.uploadFile(testCase.BucketName, objectName, sourceFile);
            ebrains.bucket.uploadFile(testCase.BucketName, takenName, sourceFile);

            % An object that has the target name stops the rename before
            % the request.
            testCase.verifyError( ...
                @() ebrains.bucket.renameObject(testCase.BucketName, objectName, takenName), ...
                'EBRAINS:Bucket:TargetExists');

            ebrains.bucket.renameObject(testCase.BucketName, objectName, newName);

            % The proxy completes the rename in the background after it has
            % answered, so the renamed object is awaited.
            testCase.assertTrue(waitForObject(testCase.BucketName, newName), ...
                'The renamed object did not appear in the bucket within the wait.');
            testCase.verifyEqual(ebrains.bucket.getFileSize(testCase.BucketName, newName), sourceSizeBytes);
            testCase.assertTrue(waitForObject(testCase.BucketName, objectName, Present=false), ...
                'The object is still listed under its old name after the rename.');
            testCase.verifyError( ...
                @() ebrains.bucket.renameObject(testCase.BucketName, objectName, newName), ...
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

            resumeFolder = fullfile(folderFixture.Folder, "multipart-uploads");
            ebrains.bucket.uploadFile(testCase.BucketName, objectName, sourceFile, ...
                MultipartThreshold=2^20, PartSize=partSizeBytes, DisplayMode="Command Window", ...
                ResumeFolder=resumeFolder);
            testCase.verifyTrue(isfolder(resumeFolder), ...
                'The upload records its progress in ResumeFolder.');
            testCase.verifyEmpty(dir(fullfile(resumeFolder, "*.json")), ...
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

function isSettled = waitForObject(bucketName, objectName, options)
% waitForObject - Poll the bucket until the object is present (or absent) or the wait runs out
%
%   The proxy answers a rename or copy before it has completed it, so a
%   test checks the result by polling the listing for up to a minute.
    arguments
        bucketName (1,1) string
        objectName (1,1) string
        options.Present (1,1) logical = true
        options.TimeoutSeconds (1,1) double = 60
    end
    tBegin = tic;
    isSettled = false;
    while ~isSettled && toc(tBegin) < options.TimeoutSeconds
        client = ebrains.bucket.api.BucketsClient();
        isPresent = ebrains.bucket.internal.hasObject(client, bucketName, objectName);
        isSettled = isPresent == options.Present;
        if ~isSettled
            pause(2)
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
