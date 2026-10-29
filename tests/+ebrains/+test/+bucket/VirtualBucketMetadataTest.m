classdef VirtualBucketMetadataTest < matlab.unittest.TestCase
    % VirtualBucketMetadataTest - Tests of the .ebrains folder of a virtual bucket
    %
    % The folder is laid out as spec/README.md#virtual-buckets of the
    % ebrains-bucket-sync package describes. createVirtualBucket writes it,
    % and the sync functions leave it out, refuse another bucket, leave
    % placeholders alone and update the manifest. Requests go to a
    % MockBucketsClient, and transfers to stand-ins.

    properties
        Client ebrains.mocks.MockBucketsClient
        Folder string
    end

    properties (TestParameter)
        % Texts of a bucket.json that does not follow virtual-bucket.schema.json
        BadBucketInfo = struct( ...
            "NotJson", '{"format_version": 1,', ...
            "NotAnObject", '[1, 2]', ...
            "VersionNotWhole", '{"format_version": 1.5, "bucket": "b", "prefix": "", "listed_at": null}', ...
            "VersionTrue", '{"format_version": true, "bucket": "b", "prefix": "", "listed_at": null}', ...
            "EmptyBucket", '{"format_version": 1, "bucket": "", "prefix": "", "listed_at": null}', ...
            "PrefixWithoutSlash", '{"format_version": 1, "bucket": "b", "prefix": "set", "listed_at": null}', ...
            "PrefixThatLeaves", '{"format_version": 1, "bucket": "b", "prefix": "../set/", "listed_at": null}', ...
            "PrefixWithDrive", '{"format_version": 1, "bucket": "b", "prefix": "C:/set/", "listed_at": null}', ...
            "NoListedAt", '{"format_version": 1, "bucket": "b", "prefix": ""}', ...
            "ListedAtWithOffset", '{"format_version": 1, "bucket": "b", "prefix": "", "listed_at": "2024-01-02T03:04:05+00:00"}', ...
            "ListedAtOnFebruary30", '{"format_version": 1, "bucket": "b", "prefix": "", "listed_at": "2024-02-30T00:00:00Z"}')

        % Texts of a manifest whose only times are of a day that does not exist
        ManifestOfImpossibleDates = struct( ...
            "OneRow", "path,bytes,modified_time,hash" + newline + ...
                "a.txt,1,2024-02-30T00:00:00Z," + newline, ...
            "TwoRows", "path,bytes,modified_time,hash" + newline + ...
                "a.txt,1,2024-02-30T00:00:00Z," + newline + ...
                "b.txt,1,2024-02-30T00:00:00Z," + newline)
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            testCase.Client = ebrains.mocks.MockBucketsClient();
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = string(folderFixture.Folder);
        end
    end

    methods (Test)
        %% Files of the .ebrains folder
        function testManifestRoundTripQuotesWhereNeeded(testCase)
            % The text is that of the paths-that-need-quotes fixture of the spec
            text = "path,bytes,modified_time,hash" + newline + ...
                """a,b.txt"",1,," + newline + ...
                "måling/data file.txt,3,2024-01-02T03:04:05Z,900150983cd24fb0d6963f7d28e17f72" + newline + ...
                """say """"hi"""".txt"",2,," + newline;

            files = ebrains.bucket.internal.metadata.parseManifest(text);

            testCase.verifyEqual(files.Path, ["a,b.txt"; "måling/data file.txt"; "say ""hi"".txt"]);
            testCase.verifyEqual(files.Bytes, [1; 3; 2]);
            testCase.verifyEqual(files.ModifiedTime(2), datetime(2024, 1, 2, 3, 4, 5, TimeZone="UTC"));
            testCase.verifyEqual(ebrains.bucket.internal.metadata.formatManifest(files), text);
        end

        function testManifestWithoutHeaderIsRejected(testCase)
            testCase.verifyError(@() ebrains.bucket.internal.metadata.parseManifest("a.txt,1,,"), ...
                'EBRAINS:Bucket:InvalidManifest');
        end

        function testManifestOfImpossibleDatesIsRefusedAtItsLine(testCase, ManifestOfImpossibleDates)
            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.parseManifest(ManifestOfImpossibleDates);
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the manifest to be refused.");
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidManifest');
            testCase.verifyThat(exception.message, ...
                matlab.unittest.constraints.StartsWithSubstring("Line 2: "));
        end

        function testBucketInfoRoundTripKeepsUnknownFields(testCase)
            metadataFolder = fullfile(testCase.Folder, ".ebrains");
            mkdir(metadataFolder)
            writeFile(fullfile(metadataFolder, "bucket.json"), ...
                '{"format_version": 1, "bucket": "b", "prefix": "", "listed_at": null, "note": "x"}');
            listedTime = datetime(2024, 1, 2, 3, 4, 5, TimeZone="UTC");

            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "/set", listedTime);

            data = jsondecode(fileread(fullfile(metadataFolder, "bucket.json")));
            testCase.verifyEqual(data.note, 'x');
            testCase.verifyEqual(data.listed_at, '2024-01-02T03:04:05Z');
            info = ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder);
            testCase.verifyEqual(info.BucketName, "my-bucket");
            testCase.verifyEqual(info.Prefix, "set/");
            testCase.verifyEqual(info.ListedTime, listedTime);
        end

        function testNeverListedBucketIsWrittenAsNull(testCase)
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");

            text = fileread(fullfile(testCase.Folder, ".ebrains", "bucket.json"));
            testCase.verifySubstring(text, '"listed_at": null');
            testCase.verifyTrue(isnat(ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder).ListedTime));
        end

        function testNewerFormatVersionIsRefused(testCase)
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            writeFile(fullfile(testCase.Folder, ".ebrains", "bucket.json"), ...
                '{"format_version": 2, "bucket": "b", "prefix": "", "listed_at": null}');

            testCase.verifyError(@() ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder), ...
                'EBRAINS:Bucket:UnknownVirtualBucketFormat');
        end

        function testBucketInfoThatBreaksTheSchemaIsRefused(testCase, BadBucketInfo)
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            writeFile(fullfile(testCase.Folder, ".ebrains", "bucket.json"), BadBucketInfo);

            testCase.verifyError(@() ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder), ...
                'EBRAINS:Bucket:InvalidBucketInfo');
        end

        function testInvalidManifestErrorNamesFileAndLine(testCase)
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            manifestFile = fullfile(testCase.Folder, ".ebrains", "manifest.csv");
            writeFile(manifestFile, "path,bytes,modified_time,hash" + newline + "a.txt,1,," + newline + "../x.txt,1,," + newline);

            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the manifest to be refused.");
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidManifest');
            testCase.verifySubstring(exception.message, sprintf('"%s", line 3: the path "../x.txt"', manifestFile));
        end

        function testManifestThatIsNotUtf8IsRefused(testCase)
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            fileID = fopen(fullfile(testCase.Folder, ".ebrains", "manifest.csv"), "w");
            fwrite(fileID, [unicode2native(char("path,bytes,modified_time,hash" + newline + "m"), "UTF-8"), ...
                uint8(229), unicode2native(char("ling.txt,1,," + newline), "UTF-8")]); % "å" in Latin-1
            fclose(fileID);

            testCase.verifyError(@() ebrains.bucket.internal.metadata.readManifest(testCase.Folder), ...
                'EBRAINS:Bucket:NotUTF8Text');
        end

        function testEmptyManifestIsRefusedAtItsFirstLine(testCase)
            % An empty file is UTF-8 text without the header line
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            writeFile(fullfile(testCase.Folder, ".ebrains", "manifest.csv"), "");

            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the manifest to be refused.");
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidManifest');
            testCase.verifySubstring(exception.message, "line 1:");
        end

        function testRuleBrokenBeforeASyntaxErrorIsReportedFirst(testCase)
            % The rows before a quoting error are read, so a rule broken
            % on an earlier line is the first line that breaks the layout
            text = "path,bytes,modified_time,hash" + newline + "../x.txt,1,," + newline + """unclosed,1,," + newline;

            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.parseManifest(text);
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the manifest to be refused.");
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidManifest');
            testCase.verifySubstring(exception.message, 'Line 2: the path "../x.txt"');
        end

        function testSyntaxErrorAfterGoodRowsIsReportedAtItsLine(testCase)
            text = "path,bytes,modified_time,hash" + newline + "a.txt,1,," + newline + """unclosed,1,," + newline;

            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.parseManifest(text);
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the manifest to be refused.");
            testCase.verifySubstring(exception.message, "Line 3: it is not a row of CSV text (a quoted field is not closed)");
        end

        function testSyntaxErrorOnTheFirstLineIsReportedAsSuch(testCase)
            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.parseManifest("""path,bytes,modified_time,hash");
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the manifest to be refused.");
            testCase.verifySubstring(exception.message, "Line 1: it is not a row of CSV text");
        end

        function testEmptyBucketInfoIsRefusedAsNotJson(testCase)
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            writeFile(fullfile(testCase.Folder, ".ebrains", "bucket.json"), "");

            exception = MException.empty;
            try
                ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder);
            catch exception
            end

            testCase.assertNotEmpty(exception, "Expected the file to be refused.");
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidBucketInfo');
            testCase.verifySubstring(exception.message, "it is not JSON text in UTF-8");
        end

        function testUnreadableBucketInfoIsReportedAsUnreadable(testCase)
            % A file that cannot be opened is not bad JSON
            mkdir(fullfile(testCase.Folder, ".ebrains"))
            bucketInfoFile = fullfile(testCase.Folder, ".ebrains", "bucket.json");
            writeFile(bucketInfoFile, '{"format_version": 1, "bucket": "b", "prefix": "", "listed_at": null}');
            makeFileUnreadable(testCase, bucketInfoFile);

            testCase.verifyError(@() ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder), ...
                'EBRAINS:Bucket:CouldNotReadFile');
        end

        function testManifestWithCarriageReturnsIsRead(testCase)
            crlf = char([13 10]);
            files = ebrains.bucket.internal.metadata.parseManifest( ...
                "path,bytes,modified_time,hash" + crlf + "a.txt,1,2024-01-02T03:04:05Z," + crlf);

            testCase.verifyEqual(files.Path, "a.txt");
            testCase.verifyEqual(files.ModifiedTime, datetime(2024, 1, 2, 3, 4, 5, TimeZone="UTC"));
        end

        %% createVirtualBucket
        function testCreateVirtualBucketRecordsBucketAndListing(testCase)
            addListing(testCase.Client, ["set/a.txt", "set/sub/b.txt"], [3, 4]);

            ebrains.bucket.createVirtualBucket("my-bucket", testCase.Folder, Prefix="set", ...
                Client=testCase.Client);

            info = ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder);
            testCase.verifyEqual([info.BucketName, info.Prefix], ["my-bucket", "set/"]);
            testCase.verifyFalse(isnat(info.ListedTime));
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "sub/b.txt"]);
            testCase.verifyEqual(manifest.Bytes, [3; 4]);
        end

        function testCreateVirtualBucketSkipsMetadataObjects(testCase)
            addListing(testCase.Client, ["a.txt", ".ebrains/manifest.csv"], [3, 3]);

            ebrains.bucket.createVirtualBucket("my-bucket", testCase.Folder, Client=testCase.Client);

            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, "a.txt");
            testCase.verifySubstring(fileread(fullfile(testCase.Folder, ".ebrains", "manifest.csv")), ...
                'a.txt,3', 'The object named like the manifest does not replace it.');
        end

        function testCreateVirtualBucketLeavesOutUnsafeNames(testCase)
            % The files, the folders and the manifest come from one checked
            % listing, so an object whose name leaves the root is in none
            % of them, folder objects included. BucketFunctionsTest covers
            % which kinds of names are left out.
            addListing(testCase.Client, ["../outside.txt", "a.txt", "../out/", "empty/"], [3, 3, 0, 0]);

            testCase.verifyWarning(@() ebrains.bucket.createVirtualBucket("my-bucket", testCase.Folder, ...
                Client=testCase.Client), 'EBRAINS:Bucket:UnsafeObjectName');

            testCase.verifyFalse(isfile(fullfile(testCase.Folder, "..", "outside.txt")));
            testCase.verifyFalse(isfolder(fullfile(testCase.Folder, "..", "out")));
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "a.txt")));
            testCase.verifyTrue(isfolder(fullfile(testCase.Folder, "empty")), ...
                'A folder object without files below it is created as a folder.');
            testCase.verifyEqual(ebrains.bucket.internal.metadata.readManifest(testCase.Folder).Path, "a.txt");
        end

        function testCreateVirtualBucketRefusesPrefixWithDrive(testCase)
            % The prefix is checked before the bucket is listed, so no
            % request is sent and no folder is created
            target = fullfile(testCase.Folder, "virtual");

            testCase.verifyError(@() ebrains.bucket.createVirtualBucket("my-bucket", target, ...
                Prefix="C:/set", Client=testCase.Client), 'EBRAINS:Bucket:InvalidPrefix');

            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
            testCase.verifyFalse(isfolder(target));
        end

        function testCreateVirtualBucketRefusesOtherBucket(testCase)
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");

            testCase.verifyError(@() ebrains.bucket.createVirtualBucket("other-bucket", testCase.Folder, ...
                Client=testCase.Client), 'EBRAINS:Bucket:OtherBucket');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        %% Sync
        function testSyncLeavesMetadataFolderOut(testCase)
            writeFile(fullfile(testCase.Folder, ".ebrains", "notes.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            addListing(testCase.Client, [".ebrains/bucket.json", "a.txt"], [3, 3]);

            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", Delete=true, ...
                Comparison="Size", Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, "a.txt", ...
                'Neither the local .ebrains folder nor the object below .ebrains/ is planned.');
            testCase.verifyEqual(actions.Action, "none");
        end

        function testSyncRefusesPrefixWithDriveBeforeListing(testCase)
            % Both sync functions normalize the prefix in runSync before
            % the bucket is listed, so one direction covers them
            testCase.verifyError(@() ebrains.bucket.sync.fromBucket("my-bucket", testCase.Folder, ...
                Prefix="c:set", Client=testCase.Client, Verbose=false), 'EBRAINS:Bucket:InvalidPrefix');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testSyncOfOtherBucketIsRefusedBeforeListing(testCase)
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "set/");

            testCase.verifyError(@() ebrains.bucket.sync.fromBucket("my-bucket", testCase.Folder, ...
                Client=testCase.Client, Verbose=false), 'EBRAINS:Bucket:Sync:OtherBucket');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testDryRunOfOtherBucketShowsPlanWithRefusal(testCase)
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "other-bucket", "");
            addListing(testCase.Client, "a.txt", 3);

            actions = ebrains.bucket.sync.fromBucket("my-bucket", testCase.Folder, DryRun=true, ...
                Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Action, "download");
            testCase.verifyEqual(actions.Status, "skipped");
            testCase.verifySubstring(char(actions.Message), 'virtual bucket of bucket "other-bucket"');
        end

        function testPushLeavesPlaceholdersAlone(testCase)
            % The placeholder of a.txt must not replace its object, and that
            % of gone.txt must not be uploaded although its object is gone.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            writeFile(fullfile(testCase.Folder, "gone.txt"), "");
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");

            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", Delete=true, ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Action, ["none"; "none"]);
            testCase.verifyEqual(actions.Reason, ["placeholder"; "placeholder"]);
        end

        function testPushWithoutManifestLeavesPlaceholdersAlone(testCase)
            % A virtual bucket registered without a listing has no
            % manifest, so the listing the sync makes must tell the
            % placeholders apart.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            writeFile(fullfile(testCase.Folder, "empty.txt"), "");
            % Uploaded after the local files were written, so the empty
            % object is unchanged rather than newer locally
            addListing(testCase.Client, ["a.txt", "empty.txt"], [3, 0], "2100-01-01T00:00:00");

            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, ["a.txt"; "empty.txt"]);
            testCase.verifyEqual(actions.Reason, ["placeholder"; "unchanged"]);
        end

        function testPushProtectsPlaceholderWhoseObjectGrewSinceListing(testCase)
            % The manifest has the object at 0 bytes; the bucket now holds
            % content, which the empty local file must not replace.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, makeFiles("a.txt", 0));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");

            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Reason, "placeholder");
        end

        function testPushUpdatesManifest(testCase)
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            writeFile(fullfile(testCase.Folder, "new.txt"), "abcd");
            addListing(testCase.Client, ["kept.txt", "extra.txt"], [3, 3], "2000-01-01T00:00:00");
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/upload?sig=1'));
            testCase.Client.addResponse('OK', struct());
            writeFile(fullfile(testCase.Folder, "kept.txt"), "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["kept.txt", "extra.txt"], [3, 3]));

            ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", Delete=true, ...
                Uploader=@acceptUpload, Client=testCase.Client, Verbose=false);

            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["kept.txt"; "new.txt"]);
            testCase.verifyEqual(manifest.Bytes, [3; 4]);
            testCase.verifyTrue(isnat(manifest.ModifiedTime(2)), ...
                'The time of an uploaded object is only known from a new listing.');
            testCase.verifyEqual(manifest.Hash(2), ...
                ebrains.bucket.sync.internal.computeMD5(fullfile(testCase.Folder, "new.txt")), ...
                'The manifest records the checksum of an uploaded file.');
        end

        function testPushRecordsTheChecksumOfTheContentItSent(testCase)
            % The checksum is read before the upload, so an edit made while
            % the file is being uploaded does not end up in the manifest
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            writeFile(fullfile(testCase.Folder, "new.txt"), "abc");
            addListing(testCase.Client, "other.txt", 3, "2000-01-01T00:00:00");
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/upload?sig=1'));
            testCase.Client.addResponse('OK', struct());

            ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                Uploader=@editThenAccept, Client=testCase.Client, Verbose=false);

            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Hash(manifest.Path == "new.txt"), "900150983cd24fb0d6963f7d28e17f72", ...
                'The manifest holds the checksum of the content that was sent, "abc".');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "new.txt")), 'xyz');
        end

        function testPullWritesListingAsManifest(testCase)
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            addListing(testCase.Client, ["a.txt", "b.txt"], [3, 3], "2000-01-01T00:00:00");
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=2'));

            ebrains.bucket.sync.fromBucket("my-bucket", testCase.Folder, Exclude="b.txt", ...
                Downloader=@writeAbc, Client=testCase.Client, Verbose=false);

            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "b.txt"], ...
                'The manifest is the listing before exclude patterns.');
            info = ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder);
            testCase.verifyFalse(isnat(info.ListedTime));
        end
    end

    methods (Test) % Placeholders of removed objects
        function testPushKeepsProtectingPlaceholderOfRemovedObject(testCase)
            % The object of gone.txt was removed. Its entry must outlive the
            % first sync, or the second one uploads an empty object.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            writeFile(fullfile(testCase.Folder, "gone.txt"), "");

            for iSync = 1:2
                addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
                actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                    Uploader=@failUpload, Client=testCase.Client, Verbose=false);

                testCase.verifyEqual(actions.Reason, ["placeholder"; "placeholder"], ...
                    sprintf('Sync %d must leave both placeholders alone.', iSync));
            end
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "gone.txt"]);
        end

        function testPushKeepsProtectingExcludedPlaceholderOfRemovedObject(testCase)
            % The manifest is made before the exclude patterns, so the
            % entry of an excluded placeholder survives a push that leaves
            % the file out, and the next push without the pattern still
            % knows the file for a placeholder rather than upload an empty
            % object. Mirrors
            % test_placeholder_of_a_removed_object_stays_protected_in_the_next_push
            % of the ebrains-bucket-sync package.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "excluded.txt", "gone.txt"], [3, 3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            writeFile(fullfile(testCase.Folder, "excluded.txt"), "");
            writeFile(fullfile(testCase.Folder, "gone.txt"), "");

            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", Exclude="excluded.txt", ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);
            testCase.verifyEqual(actions.Path, ["a.txt"; "gone.txt"]);
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "excluded.txt"; "gone.txt"], ...
                'The entry of the excluded placeholder survives the push.');

            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, ["a.txt"; "excluded.txt"; "gone.txt"]);
            testCase.verifyEqual(actions.Reason, repmat("placeholder", 3, 1));
        end

        function testPullKeepsEntryOfExcludedPlaceholder(testCase)
            % An excluded placeholder is not deleted, since excluded files
            % are never touched, and keeps its entry, since the manifest is
            % made before the exclude patterns: the next push without the
            % pattern must still know the file for a placeholder. Mirrors
            % test_excluded_placeholder_of_a_removed_object_is_kept of the
            % ebrains-bucket-sync package.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "gone.txt"), "");
            % Uploaded before a.txt was written, so a.txt is not downloaded
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");

            actions = ebrains.bucket.sync.fromBucket("my-bucket", testCase.Folder, Exclude="gone.txt", ...
                Downloader=@writeAbc, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, "a.txt");
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "gone.txt")));
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "gone.txt"], ...
                'The entry of the excluded placeholder survives the pull.');

            % Uploaded after a.txt was written, so a.txt is unchanged
            addListing(testCase.Client, "a.txt", 3, "2999-01-01T00:00:00");
            actions = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);

            gone = actions(actions.Path == "gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason], ["none", "placeholder"]);
        end

        function testPullDeletesPlaceholderOfRemovedObject(testCase)
            % Without Delete, a file with data and an empty file the
            % manifest does not know are kept
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt", "data.txt"], [3, 3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "gone.txt"), "");
            writeFile(fullfile(testCase.Folder, "data.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "mine.txt"), "");
            % Uploaded before a.txt was written, so a.txt is not downloaded
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");

            actions = ebrains.bucket.sync.fromBucket("my-bucket", testCase.Folder, ...
                Downloader=@writeAbc, Client=testCase.Client, Verbose=false);

            gone = actions(actions.Path == "gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason, gone.Status], ["delete", "placeholder", "done"]);
            testCase.verifyFalse(isfile(fullfile(testCase.Folder, "gone.txt")));
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "data.txt")));
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "mine.txt")));
        end

        function testPullKeepsEntryOfPlaceholderWhoseDeletionIsHeldBack(testCase)
            % The failed download holds the deletions back, so gone.txt
            % stays as an empty file. Only its manifest entry tells the
            % next sync to the bucket that it stands for an object.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            writeFile(fullfile(testCase.Folder, "gone.txt"), "");
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
            addDownloadUrl(testCase.Client);

            actions = testCase.verifyWarning(@() ebrains.bucket.sync.fromBucket("my-bucket", ...
                testCase.Folder, Downloader=@failDownload, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:Incomplete');

            gone = actions(actions.Path == "gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason, gone.Status], ["delete", "placeholder", "skipped"]);
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "gone.txt")));
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "gone.txt"]);
            testCase.verifyEqual(manifest.Bytes, [3; 3]);

            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
            pushed = ebrains.bucket.sync.toBucket(testCase.Folder, "my-bucket", ...
                Uploader=@failUpload, Client=testCase.Client, Verbose=false);

            gone = pushed(pushed.Path == "gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason], ["none", "placeholder"]);
        end

        function testPullKeepsEntryOfPlaceholderItCouldNotDelete(testCase)
            % gone.txt lies in a folder without write permission, so its
            % deletion fails and the empty file stays
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "sub/gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "sub", "gone.txt"), "");
            makeUndeletable(testCase, fullfile(testCase.Folder, "sub", "gone.txt"));
            % Uploaded before a.txt was written, so a.txt is not downloaded
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");

            actions = testCase.verifyWarning(@() ebrains.bucket.sync.fromBucket("my-bucket", ...
                testCase.Folder, Client=testCase.Client, Verbose=false), 'EBRAINS:Bucket:Sync:Incomplete');

            gone = actions(actions.Path == "sub/gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason, gone.Status], ["delete", "placeholder", "failed"]);
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "sub", "gone.txt")));
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, ["a.txt"; "sub/gone.txt"]);
        end

        function testPullGivesNoEntryToPlaceholderThatHoldsDataNow(testCase)
            % The download writes into gone.txt before it fails, as another
            % program may between the listing and the deletions. The file
            % holds data, so it is no placeholder any more and gets no entry.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            goneFile = fullfile(testCase.Folder, "gone.txt");
            writeFile(goneFile, "");
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
            addDownloadUrl(testCase.Client);
            fillGoneAndFail = @(varargin) fillPlaceholderAndFail(goneFile);

            actions = testCase.verifyWarning(@() ebrains.bucket.sync.fromBucket("my-bucket", ...
                testCase.Folder, Downloader=fillGoneAndFail, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:Incomplete');

            gone = actions(actions.Path == "gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason, gone.Status], ["delete", "placeholder", "skipped"]);
            testCase.verifyEqual(fileread(goneFile), 'new data');
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, "a.txt");
        end

        function testPullKeepsPlaceholderThatHoldsDataByTheTimeItIsDeleted(testCase)
            % The download writes into gone.txt and succeeds, so the
            % deletions run. The folder was listed before the download, when
            % gone.txt was empty, but the file holds data by the time it is
            % to be deleted, so it is kept and gets no manifest entry.
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "");
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                makeFiles(["a.txt", "gone.txt"], [3, 3]));
            writeFile(fullfile(testCase.Folder, "a.txt"), "");
            goneFile = fullfile(testCase.Folder, "gone.txt");
            writeFile(goneFile, "");
            addListing(testCase.Client, "a.txt", 3, "2000-01-01T00:00:00");
            addDownloadUrl(testCase.Client);
            fillGoneThenDownload = @(target, varargin) fillPlaceholderThenWrite(goneFile, target);

            actions = testCase.verifyWarning(@() ebrains.bucket.sync.fromBucket("my-bucket", ...
                testCase.Folder, Downloader=fillGoneThenDownload, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:PlaceholderKept');

            gone = actions(actions.Path == "gone.txt", :);
            testCase.verifyEqual([gone.Action, gone.Reason, gone.Status], ["delete", "placeholder", "skipped"]);
            testCase.verifySubstring(gone.Message, "holds data");
            testCase.verifyEqual(fileread(goneFile), 'new data');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a.txt")), 'abc');
            manifest = ebrains.bucket.internal.metadata.readManifest(testCase.Folder);
            testCase.verifyEqual(manifest.Path, "a.txt");
        end

        function testCreateVirtualBucketAgainDeletesPlaceholderOfRemovedObject(testCase)
            addListing(testCase.Client, ["a.txt", "gone.txt"], [3, 3]);
            ebrains.bucket.createVirtualBucket("my-bucket", testCase.Folder, Client=testCase.Client);
            addListing(testCase.Client, "a.txt", 3);

            ebrains.bucket.createVirtualBucket("my-bucket", testCase.Folder, Client=testCase.Client);

            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "a.txt")));
            testCase.verifyFalse(isfile(fullfile(testCase.Folder, "gone.txt")));
        end

        function testMetadataFolderIsFoundInAnyCase(testCase)
            % On a file system that ignores case, an object ".EBRAINS/x"
            % would be written into the .ebrains folder
            tf = ebrains.bucket.internal.metadata.isMetadataPath( ...
                [".ebrains"; ".EBRAINS/manifest.csv"; ".Ebrains"; ".ebrainsx/a"; "a/.ebrains"]);

            testCase.verifyEqual(tf, [true; true; true; false; false]);
        end
    end
end

function files = makeFiles(paths, bytes)
    files = ebrains.bucket.sync.internal.makeFileTable(paths, bytes);
end

function addListing(client, names, bytes, lastModified)
% addListing - Queue the single page of a listing, and the empty page that ends it
    arguments
        client
        names string
        bytes double
        lastModified (1,1) string = ""
    end
    objects = struct( ...
        'name', cellstr(reshape(names, [], 1)), ...
        'bytes', num2cell(reshape(bytes, [], 1)), ...
        'last_modified', char(lastModified), ...
        'hash', '', ...
        'content_type', 'application/octet-stream');
    client.addResponse('OK', struct('objects', objects));
    client.addResponse('OK', struct('objects', []));
end

function addDownloadUrl(client)
% addDownloadUrl - Queue the signed URL that one download asks for
    client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));
end

function [wasSuccess, response] = acceptUpload(varargin)
    wasSuccess = true;
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK);
end

function varargout = failUpload(varargin) %#ok<STOUT> errors before any output is due
% failUpload - Uploader for a sync that must upload nothing
    error('EBRAINS:Test:UnexpectedUpload', 'No file should be uploaded.')
end

function writeAbc(target, varargin)
% writeAbc - Downloader that writes three bytes to the target
    writeFile(target, "abc");
end

function varargout = failDownload(varargin) %#ok<STOUT> errors before any output is due
% failDownload - Downloader that fails, as one does when the connection is lost
    error('EBRAINS:Test:DownloadFailed', 'The download failed.')
end

function fillPlaceholderThenWrite(filePath, target)
% fillPlaceholderThenWrite - Downloader that writes data into another file, then its own target
    writeFile(filePath, "new data");
    writeFile(target, "abc");
end

function fillPlaceholderAndFail(filePath)
% fillPlaceholderAndFail - Downloader that writes data into another file, then fails
    writeFile(filePath, "new data");
    error('EBRAINS:Test:DownloadFailed', 'The download failed.')
end

function makeUndeletable(testCase, filePath)
% makeUndeletable - Take away the permission to delete a file until the test ends
%
%   A file is deleted by changing its folder, so the folder loses its write
%   permission. The test is filtered where that has no effect: on Windows,
%   which has no chmod, and for a user who can write to any folder, such
%   as root.
    testCase.assumeFalse(ispc, 'Folder permissions are set with chmod, which Windows does not have.');
    folder = fileparts(filePath);
    [status, output] = system("chmod 555 '" + folder + "'");
    testCase.assertEqual(status, 0, output);
    testCase.addTeardown(@() system("chmod 755 '" + folder + "'"));
    probeFile = fullfile(folder, "write-probe");
    fileID = fopen(probeFile, "w");
    if fileID ~= -1
        fclose(fileID);
        delete(probeFile)
    end
    testCase.assumeEqual(fileID, -1, 'This user can change a folder without write permission.');
end

function writeFile(filePath, content)
% writeFile - Write text without a trailing newline, creating folders as needed
    folder = fileparts(filePath);
    if ~isfolder(folder)
        mkdir(folder)
    end
    fileID = fopen(filePath, "w");
    fwrite(fileID, unicode2native(char(content), "UTF-8"));
    fclose(fileID);
end

function makeFileUnreadable(testCase, filePath)
% makeFileUnreadable - Take away the permission to read a file until the test ends
%
%   The test is filtered where that has no effect: on Windows, which has
%   no chmod, and for a user who can read any file, such as root.
    testCase.assumeFalse(ispc, 'File permissions are set with chmod, which Windows does not have.');
    [status, output] = system("chmod 000 '" + filePath + "'");
    testCase.assertEqual(status, 0, output);
    testCase.addTeardown(@() system("chmod 644 '" + filePath + "'"));
    fileID = fopen(filePath, "r");
    if fileID ~= -1
        fclose(fileID);
    end
    testCase.assumeEqual(fileID, -1, 'This user can read a file without read permission.');
end

function [wasSuccess, response] = editThenAccept(sourceFile, varargin)
% editThenAccept - Uploader that edits the source file during the transfer, then accepts it
    writeFile(sourceFile, "xyz");
    [wasSuccess, response] = acceptUpload(sourceFile, varargin{:});
end
