classdef BucketFunctionsTest < matlab.unittest.TestCase
    % BucketFunctionsTest - Unit tests for the functions of the ebrains.bucket namespace
    %
    % Every function receives a MockBucketsClient through its Client
    % option, so no request reaches the Data Proxy. Page fixtures are
    % column struct arrays, the shape jsondecode gives a JSON array.

    properties
        Client ebrains.mocks.MockBucketsClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockBucketsClient();
        end
    end

    methods (Test)
        %% getBucketSize / getObjectCount
        function testGetBucketSizeReturnsBytesOfStat(testCase)
            testCase.Client.addResponse('OK', makeStat(3, 4096));

            bucketSizeBytes = ebrains.bucket.getBucketSize("my-bucket", Client=testCase.Client);

            testCase.verifyEqual(bucketSizeBytes, 4096);
            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/stat');
        end

        function testGetObjectCountReturnsCountOfStat(testCase)
            testCase.Client.addResponse('OK', makeStat(3, 4096));

            n = ebrains.bucket.getObjectCount("my-bucket", Client=testCase.Client);

            testCase.verifyEqual(n, 3);
        end

        %% listBucketObjects
        function testListBucketObjectsJoinsPages(testCase)
            testCase.Client.addResponse('OK', makeStat(3, 4096));
            testCase.Client.addResponse('OK', makePage(["a.txt", "b.txt"]));
            testCase.Client.addResponse('OK', makePage("c.txt"));

            objects = ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client);

            testCase.verifyEqual({objects.name}, {'a.txt', 'b.txt', 'c.txt'});
            testCase.verifyEqual(testCase.Client.getRequestCount(), 3);
        end

        function testListBucketObjectsFirstPageHasNoMarker(testCase)
            testCase.Client.addResponse('OK', makeStat(1, 10));
            testCase.Client.addResponse('OK', makePage("a.txt"));

            ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client);

            firstPageRequest = testCase.Client.getRequest(2);
            testCase.verifyFalse(contains(char(firstPageRequest.URL.EncodedURI), 'marker='));
            testCase.Client.verifyRequestURL(2, 'limit=10000');
        end

        function testListBucketObjectsNextPageStartsAfterLastObject(testCase)
            testCase.Client.addResponse('OK', makeStat(3, 4096));
            testCase.Client.addResponse('OK', makePage(["a.txt", "b.txt"]));
            testCase.Client.addResponse('OK', makePage("c.txt"));

            ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client);

            testCase.Client.verifyRequestURL(3, 'marker=b.txt');
        end

        function testListBucketObjectsShortPageDoesNotEndListing(testCase)
            % The Data Proxy may return fewer objects than the limit before
            % the last page, so the reported count decides when to stop.
            testCase.Client.addResponse('OK', makeStat(3, 4096));
            testCase.Client.addResponse('OK', makePage("a.txt"));
            testCase.Client.addResponse('OK', makePage("b.txt"));
            testCase.Client.addResponse('OK', makePage("c.txt"));

            objects = ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client);

            testCase.verifyNumElements(objects, 3);
        end

        function testListBucketObjectsEmptyPageEndsListing(testCase)
            % An overstated count must not make the listing loop forever.
            testCase.Client.addResponse('OK', makeStat(5, 4096));
            testCase.Client.addResponse('OK', makePage(["a.txt", "b.txt"]));
            testCase.Client.addResponse('OK', makePage(string.empty));

            objects = ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client);

            testCase.verifyNumElements(objects, 2);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 3);
        end

        function testListBucketObjectsEmptyBucket(testCase)
            testCase.Client.addResponse('OK', makeStat(0, 0));
            testCase.Client.addResponse('OK', makePage(string.empty));

            objects = ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client);

            testCase.verifyEmpty(objects);
        end

        function testListBucketObjectsStatErrorPropagates(testCase)
            testCase.Client.addResponse('NotFound', 'Bucket not found');
            testCase.verifyError(...
                @() ebrains.bucket.listBucketObjects("my-bucket", Client=testCase.Client), ...
                'EBRAINS:Bucket:getBucketStat:NotFound');
        end

        %% renameObject
        function testRenameObjectIgnoresLeadingSlashes(testCase)
            testCase.Client.addResponse('OK', struct());

            ebrains.bucket.renameObject("my-bucket", "/old.txt", "/sub/new.txt", Client=testCase.Client);

            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/old.txt');
            testCase.verifyEqual(testCase.Client.getRequestPayload(1), ...
                '{"rename":{"target_name":"sub/new.txt"}}');
        end

        function testRenameObjectErrorPropagates(testCase)
            testCase.Client.addResponse('UnprocessableEntity', struct('detail', 'invalid'));
            testCase.verifyError(...
                @() ebrains.bucket.renameObject("my-bucket", "old.txt", "new.txt", Client=testCase.Client), ...
                'EBRAINS:Bucket:renameObject:UnprocessableEntity');
        end

        %% deleteObject
        function testDeleteObjectIgnoresLeadingSlash(testCase)
            testCase.Client.addResponse('OK', struct());

            ebrains.bucket.deleteObject("my-bucket", "/old.txt", Client=testCase.Client);

            testCase.Client.verifyRequestMethod(1, 'DELETE');
            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/old.txt');
        end

        function testDeleteObjectErrorPropagates(testCase)
            testCase.Client.addResponse('NotFound', struct('detail', 'Object not found'));
            testCase.verifyError(...
                @() ebrains.bucket.deleteObject("my-bucket", "old.txt", Client=testCase.Client), ...
                'EBRAINS:Bucket:deleteObject:NotFound');
        end

        %% getBucketObject
        function testGetBucketObjectErrorPropagatesBeforeDownload(testCase)
            testCase.Client.addResponse('NotFound', 'Object not found');
            testCase.verifyError(...
                @() ebrains.bucket.getBucketObject("my-bucket", "file.txt", Client=testCase.Client), ...
                'EBRAINS:Bucket:getDownloadUrl:NotFound');
        end

        %% getFileSize
        function testGetFileSizeReturnsBytesOfExactMatch(testCase)
            % The prefix listing also returns longer names, which must not
            % be mistaken for the object.
            testCase.Client.addResponse('OK', makePage(["a.txt.bak", "a.txt"], [1, 2048]));

            fileSizeBytes = ebrains.bucket.getFileSize("my-bucket", "/a.txt", Client=testCase.Client);

            testCase.verifyEqual(fileSizeBytes, 2048);
            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket?prefix=a.txt');
        end

        function testGetFileSizeMissingObject(testCase)
            testCase.Client.addResponse('OK', makePage(string.empty));
            testCase.verifyError(...
                @() ebrains.bucket.getFileSize("my-bucket", "a.txt", Client=testCase.Client), ...
                'EBRAINS:Bucket:ObjectNotFound');
        end

        function testGetFileSizeListErrorPropagates(testCase)
            testCase.Client.addResponse('NotFound', 'Bucket not found');
            testCase.verifyError(...
                @() ebrains.bucket.getFileSize("my-bucket", "a.txt", Client=testCase.Client), ...
                'EBRAINS:Bucket:listObjects:NotFound');
        end

        %% uploadFile
        function testUploadFileErrorPropagatesBeforeUpload(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            sourceFile = fullfile(folderFixture.Folder, "upload.txt");
            writelines("content", sourceFile);
            testCase.Client.addResponse('Forbidden', 'No write access');

            testCase.verifyError(...
                @() ebrains.bucket.uploadFile("my-bucket", "/file.txt", sourceFile, Client=testCase.Client), ...
                'EBRAINS:Bucket:getUploadUrl:Forbidden');
            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/file.txt');
        end

        %% downloadFile
        function testDownloadFileMissingObjectIsReportedBeforeDownload(testCase)
            testCase.Client.addResponse('NotFound', 'Object not found');
            testCase.verifyError(...
                @() ebrains.bucket.downloadFile("my-bucket", "/file.txt", "target.txt", Client=testCase.Client), ...
                'EBRAINS:Bucket:getDownloadUrl:NotFound');
            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/file.txt');
        end

        function testDownloadFileRejectsFolderAsTarget(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.verifyError(...
                @() ebrains.bucket.downloadFile("my-bucket", "file.txt", folderFixture.Folder, Client=testCase.Client), ...
                'EBRAINS:Bucket:TargetIsFolder');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testDownloadFileFailedTransferLeavesTargetUntouched(testCase)
            % A refused connection fails the transfer before any byte is
            % written. The file at the target must be as it was, and no
            % part file may remain.
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            targetFile = fullfile(folderFixture.Folder, "existing.bin");
            writelines("previous content", targetFile);
            fileInfoBefore = dir(targetFile);
            testCase.Client.addResponse('OK', struct('url', 'http://127.0.0.1:9/existing.bin'));

            testCase.verifyError(...
                @() ebrains.bucket.downloadFile("my-bucket", "existing.bin", targetFile, ...
                    Client=testCase.Client, DisplayMode="Command Window"), ...
                'MATLAB:webservices:ConnectionRefused');

            fileInfoAfter = dir(targetFile);
            testCase.verifyEqual(fileInfoAfter.bytes, fileInfoBefore.bytes);
            testCase.verifyFalse(isfile(targetFile + ".part"));
        end
    end
end

function bucketStat = makeStat(objectCount, bytes)
    bucketStat = struct('name', 'my-bucket', 'objects_count', objectCount, 'bytes', bytes);
end

function page = makePage(objectNames, byteSizes)
% makePage - Listing page as jsondecode returns it from the Data Proxy
%
%   One column struct per object, carrying the byte size the listing
%   reports. An empty JSON array decodes to [] rather than to an empty
%   struct, and the fixture keeps that shape so the code under test meets it.

    arguments
        objectNames string
        byteSizes double = zeros(size(objectNames))
    end

    if isempty(objectNames)
        page = struct('objects', []);
        return
    end
    names = cellstr(reshape(objectNames, [], 1));
    sizes = num2cell(reshape(byteSizes, [], 1));
    page = struct('objects', struct('name', names, 'bytes', sizes));
end
