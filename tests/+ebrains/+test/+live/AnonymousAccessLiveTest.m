classdef AnonymousAccessLiveTest < ebrains.test.iam.TokenClientTestCase
    % AnonymousAccessLiveTest - Live checks of requests sent without a token
    %
    % TokenClientTestCase moves the token clients of the session and
    % EBRAINS_TOKEN aside for each test, so every request here is sent
    % without a token. The public bucket is the Data Proxy bucket of a
    % released dataset; the private bucket is the one BucketLiveTest writes
    % to.
    %
    % Tagged "LiveIntegration"; see BucketLiveTest.

    properties (Constant)
        PublicBucketName = "d-ca602c23-364a-4c9b-943b-87d1b09a5821"
        PrivateBucketName = "eivihe-sandbox"
    end

    methods (Test, TestTags = {'LiveIntegration'})
        function testReadsPublicBucketWithoutToken(testCase)
            client = ebrains.bucket.api.BucketsClient();

            testCase.verifyGreaterThan(ebrains.bucket.getObjectCount(...
                testCase.PublicBucketName, Client=client), 0)

            page = client.listObjects(testCase.PublicBucketName, limit=1);
            testCase.assertNotEmpty(page.objects)

            downloadUrl = client.getDownloadUrl(testCase.PublicBucketName, page.objects(1).name);
            testCase.verifyTrue(startsWith(downloadUrl, "https://"))
        end

        function testPrivateBucketWithoutTokenIsRefused(testCase)
            testCase.verifyError(...
                @() ebrains.bucket.getObjectCount(testCase.PrivateBucketName), ...
                'EBRAINS:Bucket:getBucketStat:Unauthorized')
        end

        function testKgWithoutTokenIsRefused(testCase)
            client = ebrains.kg.api.InstancesClient();
            testCase.verifyError(@() client.listTypes(), ...
                'EBRAINS:KG_API:listTypes:Unauthorized')
        end
    end
end
