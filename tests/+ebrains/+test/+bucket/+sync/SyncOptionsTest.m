classdef SyncOptionsTest < matlab.unittest.TestCase
    % SyncOptionsTest - Unit tests for the options object of the sync functions

    methods (Test)
        function testDefaults(testCase)
            options = ebrains.bucket.sync.SyncOptions();

            testCase.verifyEqual(options.Prefix, "");
            testCase.verifyFalse(options.Delete);
            testCase.verifyEqual(options.Comparison, "SizeAndTime");
            testCase.verifyEmpty(options.Exclude);
            testCase.verifyFalse(options.DryRun);
            testCase.verifyEqual(options.MaxDelete, Inf);
            testCase.verifyTrue(options.Verbose);
            testCase.verifyEqual(options.DisplayMode, "Command Window");
            testCase.verifyEqual(options.Uploader, @ebrains.external.webprogress.upload);
            testCase.verifyEqual(options.Downloader, @ebrains.external.webprogress.download);
        end

        function testNameValuesSetProperties(testCase)
            options = ebrains.bucket.sync.SyncOptions(Delete=true, Exclude=[".git", "*.tmp"], MaxDelete=10);

            testCase.verifyTrue(options.Delete);
            testCase.verifyEqual(options.Exclude, [".git", "*.tmp"]);
            testCase.verifyEqual(options.MaxDelete, 10);
            testCase.verifyEqual(options.Comparison, "SizeAndTime", 'Unset options keep their defaults.');
        end

        function testFromStructMatchesNameValues(testCase)
            options = ebrains.bucket.sync.SyncOptions.fromStruct(struct('DryRun', true, 'Prefix', "sub/"));

            testCase.verifyTrue(options.DryRun);
            testCase.verifyEqual(options.Prefix, "sub/");
        end

        function testInvalidComparisonIsRejected(testCase)
            testCase.verifyError(@() ebrains.bucket.sync.SyncOptions(Comparison="Hash"), ...
                ?MException);
        end

        function testUnknownOptionIsRejected(testCase)
            testCase.verifyError(@() ebrains.bucket.sync.SyncOptions(Colour="red"), ...
                ?MException);
        end

        function testSyncFunctionsRejectAnUnknownOption(testCase)
            % The sync functions take the options of the class and Client,
            % and nothing else.
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            client = ebrains.mocks.MockBucketsClient();

            testCase.verifyError(@() ebrains.bucket.sync.toBucket(folderFixture.Folder, "my-bucket", ...
                Colour="red", Client=client), ?MException);
            testCase.verifyEqual(client.getRequestCount(), 0);
        end
    end
end
