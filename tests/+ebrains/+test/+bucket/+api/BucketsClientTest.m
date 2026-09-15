classdef BucketsClientTest < matlab.unittest.TestCase
    % BucketsClientTest - Unit tests for ebrains.bucket.api.BucketsClient
    %
    % Uses MockBucketsClient so that no request reaches the Data Proxy.

    properties
        Client ebrains.mocks.MockBucketsClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockBucketsClient();
        end
    end

    methods (Test)
        %% getBucketStat
        function testGetBucketStatSuccess(testCase)
            bucketStat = struct('name', 'my-bucket', 'objects_count', 3, 'bytes', 1024);
            testCase.Client.addResponse('OK', bucketStat);

            result = testCase.Client.getBucketStat("my-bucket");

            testCase.verifyEqual(result, bucketStat);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, ...
                'https://data-proxy.ebrains.eu/api/v1/buckets/my-bucket/stat');
        end

        function testGetBucketStatNotFound(testCase)
            testCase.Client.addResponse('NotFound', struct('detail', 'Bucket not found'));
            testCase.verifyError(@() testCase.Client.getBucketStat("my-bucket"), ...
                'EBRAINS:Bucket:getBucketStat:NotFound');
        end

        %% listObjects
        function testListObjectsSuccess(testCase)
            page = struct('objects', struct('name', {'a.txt'; 'b.txt'}));
            testCase.Client.addResponse('OK', page);

            result = testCase.Client.listObjects("my-bucket");

            testCase.verifyEqual(result, page);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, 'https://data-proxy.ebrains.eu/api/v1/buckets/my-bucket');
        end

        function testListObjectsPassesQueryParameters(testCase)
            testCase.Client.addResponse('OK', struct('objects', []));

            testCase.Client.listObjects("my-bucket", limit=100, marker="last.txt", prefix="sub");

            testCase.Client.verifyRequestURL(1, 'limit=100');
            testCase.Client.verifyRequestURL(1, 'marker=last.txt');
            testCase.Client.verifyRequestURL(1, 'prefix=sub');
        end

        function testListObjectsServerError(testCase)
            testCase.Client.addResponse('InternalServerError', []);
            testCase.verifyError(@() testCase.Client.listObjects("my-bucket"), ...
                'EBRAINS:Bucket:listObjects:InternalServerError');
        end

        %% getDownloadUrl
        function testGetDownloadUrlReturnsTemporaryUrl(testCase)
            testCase.Client.addResponse('OK', struct('url', 'https://swift.example.org/tmp?sig=1'));

            downloadUrl = testCase.Client.getDownloadUrl("my-bucket", "file.txt");

            testCase.verifyEqual(downloadUrl, "https://swift.example.org/tmp?sig=1");
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/api/v1/buckets/my-bucket/file.txt?redirect=0');
        end

        function testGetDownloadUrlSendsFoldersAsPathSegments(testCase)
            % Folders in the name are path separators to the Data Proxy.
            % Sent as %2F, the temporary URL it signs is refused by the
            % object store.
            testCase.Client.addResponse('OK', struct('url', 'https://swift.example.org/tmp'));

            testCase.Client.getDownloadUrl("my-bucket", "sub dir/file name.txt");

            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/sub%20dir/file%20name.txt');
        end

        function testGetDownloadUrlEncodesRawCharactersInReturnedUrl(testCase)
            % The Data Proxy hands out temporary URLs with raw spaces in the
            % object path and in the content-disposition value.
            testCase.Client.addResponse('OK', struct('url', ...
                'https://rgw.example.org/b/blå fil.png?response-content-disposition=attachment; filename=blå fil.png&X-Amz-Signature=1'));

            downloadUrl = testCase.Client.getDownloadUrl("my-bucket", "blå fil.png");

            testCase.verifyEqual(downloadUrl, ...
                "https://rgw.example.org/b/bl%C3%A5%20fil.png?response-content-disposition=attachment;%20filename=bl%C3%A5%20fil.png&X-Amz-Signature=1");
        end

        function testGetDownloadUrlLeavesEncodedUrlUnchanged(testCase)
            testCase.Client.addResponse('OK', struct('url', 'https://rgw.example.org/b/a%20file.png?x=%2F&y=1'));

            downloadUrl = testCase.Client.getDownloadUrl("my-bucket", "a file.png");

            testCase.verifyEqual(downloadUrl, "https://rgw.example.org/b/a%20file.png?x=%2F&y=1");
        end

        function testGetDownloadUrlPassesOptionalParameters(testCase)
            testCase.Client.addResponse('OK', struct('url', 'https://swift.example.org/tmp'));

            testCase.Client.getDownloadUrl("my-bucket", "file.txt", inline=true, ttl=60);

            testCase.Client.verifyRequestURL(1, 'inline=1');
            testCase.Client.verifyRequestURL(1, 'ttl=60');
        end

        function testGetDownloadUrlNotFound(testCase)
            testCase.Client.addResponse('NotFound', 'Object not found');
            testCase.verifyError(@() testCase.Client.getDownloadUrl("my-bucket", "file.txt"), ...
                'EBRAINS:Bucket:getDownloadUrl:NotFound');
        end

        %% getUploadUrl
        function testGetUploadUrlReturnsTemporaryUrl(testCase)
            testCase.Client.addResponse('OK', struct('url', 'https://swift.example.org/up?sig=1'));

            uploadUrl = testCase.Client.getUploadUrl("my-bucket", "sub dir/file.txt");

            testCase.verifyEqual(uploadUrl, "https://swift.example.org/up?sig=1");
            testCase.Client.verifyRequestMethod(1, 'PUT');
            testCase.Client.verifyRequestURL(1, '/api/v1/buckets/my-bucket/sub%20dir/file.txt');
        end

        function testGetUploadUrlSendsNoBodyAndNoQuery(testCase)
            testCase.Client.addResponse('OK', struct('url', 'https://swift.example.org/up'));

            testCase.Client.getUploadUrl("my-bucket", "file.txt");

            request = testCase.Client.getRequest(1);
            testCase.verifyEmpty(request.RequestMessage.Body);
            testCase.verifyFalse(contains(char(request.URL.EncodedURI), '?'));
        end

        function testGetUploadUrlValidationError(testCase)
            testCase.Client.addResponse('UnprocessableEntity', struct('detail', 'invalid name'));
            testCase.verifyError(@() testCase.Client.getUploadUrl("my-bucket", "file.txt"), ...
                'EBRAINS:Bucket:getUploadUrl:UnprocessableEntity');
        end

        %% renameObject
        function testRenameObjectKeepsTrailingSlashOfFolderName(testCase)
            testCase.Client.addResponse('OK', struct());

            testCase.Client.renameObject("my-bucket", "old folder/", "new folder/");

            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/old%20folder/');
        end

        function testRenameObjectSendsPatchWithPayload(testCase)
            testCase.Client.addResponse('OK', struct());

            testCase.Client.renameObject("my-bucket", "old.txt", "new.txt");

            testCase.Client.verifyRequestMethod(1, 'PATCH');
            testCase.Client.verifyRequestURL(1, '/api/v1/buckets/my-bucket/old.txt');
            testCase.verifyEqual(testCase.Client.getRequestPayload(1), ...
                '{"rename":{"target_name":"new.txt"}}');
        end

        function testRenameObjectValidationError(testCase)
            testCase.Client.addResponse('UnprocessableEntity', struct('detail', 'invalid name'));
            testCase.verifyError(@() testCase.Client.renameObject("my-bucket", "old.txt", "new.txt"), ...
                'EBRAINS:Bucket:renameObject:UnprocessableEntity');
        end
    end
end
