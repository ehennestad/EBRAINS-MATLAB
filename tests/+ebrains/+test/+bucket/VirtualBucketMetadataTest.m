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
                "måling/data file.txt,3,2024-01-02T03:04:05Z,abc" + newline + ...
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
end

function files = makeFiles(paths, bytes)
    files = ebrains.bucket.sync.internal.makeFileTable(paths, bytes);
end

function addListing(client, names, bytes, lastModified)
% addListing - Queue the stat and the single page of a listing
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
    client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', numel(objects), 'bytes', 0));
    client.addResponse('OK', struct('objects', objects));
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
