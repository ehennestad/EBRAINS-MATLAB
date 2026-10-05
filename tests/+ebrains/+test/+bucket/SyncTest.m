classdef SyncTest < matlab.unittest.TestCase
    % SyncTest - Unit tests for syncing local folders with Data Proxy buckets
    %
    % The planning and listing helpers are tested on their own, and
    % ebrains.bucket.syncToBucket and ebrains.bucket.syncFromBucket with a
    % MockBucketsClient and stand-ins for the uploader and downloader, so
    % no request reaches the Data Proxy. A listing is answered by two
    % canned responses: the bucket stat, whose object count ends the
    % listing, and one page.

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
        %% planSync
        function testPlanCopiesNewAndChangedFilesAndKeepsExtraneousOnes(testCase)
            source = makeFiles(["new.txt", "same.txt", "grown.txt"], [1, 2, 30]);
            target = makeFiles(["same.txt", "grown.txt", "extra.txt"], [2, 3, 4]);

            plan = ebrains.bucket.internal.planSync(source, target);

            testCase.verifyEqual(plan.Path, ["extra.txt"; "grown.txt"; "new.txt"; "same.txt"]);
            testCase.verifyEqual(plan.Action, ["none"; "copy"; "copy"; "none"]);
            testCase.verifyEqual(plan.Reason, ["extraneous"; "size"; "new"; "unchanged"]);
            testCase.verifyEqual(plan.Bytes, [4; 30; 1; 2]);
        end

        function testPlanDeletesExtraneousFilesWhenAsked(testCase)
            source = makeFiles("a.txt", 1);
            target = makeFiles(["a.txt", "extra.txt"], [1, 4]);

            plan = ebrains.bucket.internal.planSync(source, target, Delete=true);

            testCase.verifyEqual(plan.Action, ["none"; "delete"]);
        end

        function testPlanCopiesFileChangedAfterTarget(testCase)
            t0 = datetime(2024, 1, 1, 12, 0, 0, 'TimeZone', 'UTC');
            source = makeFiles(["changed.txt", "older.txt", "within.txt"], [1, 1, 1], ...
                [t0 + hours(1), t0 - hours(1), t0 + seconds(1)]);
            target = makeFiles(["changed.txt", "older.txt", "within.txt"], [1, 1, 1], ...
                [t0, t0, t0]);

            plan = ebrains.bucket.internal.planSync(source, target);

            testCase.verifyEqual(plan.Reason, ["newer"; "unchanged"; "unchanged"]);
        end

        function testPlanBySizeIgnoresTime(testCase)
            t0 = datetime(2024, 1, 1, 'TimeZone', 'UTC');
            source = makeFiles("a.txt", 1, t0 + days(1));
            target = makeFiles("a.txt", 1, t0);

            plan = ebrains.bucket.internal.planSync(source, target, Comparison="Size");

            testCase.verifyEqual(plan.Action, "none");
        end

        function testPlanLeavesFileOfUnknownTime(testCase)
            source = makeFiles("a.txt", 1, datetime(2024, 1, 1, 'TimeZone', 'UTC'));
            target = makeFiles("a.txt", 1);

            plan = ebrains.bucket.internal.planSync(source, target);

            testCase.verifyEqual(plan.Reason, "unchanged");
        end

        function testPlanByChecksumComparesContentOfSameSize(testCase)
            % The checksum decides where it is known on both sides, even
            % against the time, and the time decides where it is not.
            t0 = datetime(2024, 1, 1, 'TimeZone', 'UTC');
            source = makeFiles(["edited.txt", "same.txt", "unknown.txt"], [1, 1, 1], ...
                [t0, t0 + days(1), t0 + days(1)], ["aaa", "bbb", ""]);
            target = makeFiles(["edited.txt", "same.txt", "unknown.txt"], [1, 1, 1], ...
                [t0 + days(1), t0, t0], ["ccc", "BBB", "ddd"]);

            plan = ebrains.bucket.internal.planSync(source, target, Comparison="Checksum");

            testCase.verifyEqual(plan.Reason, ["checksum"; "unchanged"; "newer"]);
        end

        function testPlanOfEmptySides(testCase)
            empty = makeFiles(strings(0, 1), zeros(0, 1));

            plan = ebrains.bucket.internal.planSync(empty, empty);

            testCase.verifyEqual(height(plan), 0);
            testCase.verifyEqual(plan.Properties.VariableNames, {'Path', 'Action', 'Reason', 'Bytes'});
        end

        %% excludeFiles
        function testExcludeMatchesNamesAtAnyDepthAndAnchoredPaths(testCase)
            files = makeFiles(["a.tmp", "sub/b.tmp", "sub/b.tmpx", ".git/config", ...
                "src/.git/HEAD", "raw/scratch/x.dat", "other/raw/scratch/y.dat", "keep.txt"], ...
                ones(1, 8));

            kept = ebrains.bucket.internal.excludeFiles(files, ["*.tmp", ".git", "/raw/scratch"]);

            testCase.verifyEqual(kept.Path, ["sub/b.tmpx"; "other/raw/scratch/y.dat"; "keep.txt"]);
        end

        function testExcludeIgnoresTrailingSlashLikeGitignore(testCase)
            files = makeFiles([".git/config", "src/.git/HEAD", "build/a.o", "raw/scratch/x.dat", ...
                "other/raw/scratch/y.dat", "keep.txt"], ones(1, 6));

            kept = ebrains.bucket.internal.excludeFiles(files, [".git/", "build/", "/raw/scratch/"]);

            testCase.verifyEqual(kept.Path, ["other/raw/scratch/y.dat"; "keep.txt"]);
        end

        function testExcludeEscapesRegularExpressionCharacters(testCase)
            files = makeFiles(["a(1).txt", "a1.txt", "sub/x.y", "sub/xzy"], ones(1, 4));

            kept = ebrains.bucket.internal.excludeFiles(files, ["a(?).txt", "sub/x.y"]);

            testCase.verifyEqual(kept.Path, ["a1.txt"; "sub/xzy"]);
        end

        %% listLocalFiles
        function testListLocalFilesGivesRelativePathsWithSlashes(testCase)
            writeFile(fullfile(testCase.Folder, "top.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "sub", "deeper", "inner.txt"), "abcdef");
            mkdir(fullfile(testCase.Folder, "empty"));

            files = ebrains.bucket.internal.listLocalFiles(testCase.Folder);

            files = sortrows(files, "Path");
            testCase.verifyEqual(files.Path, ["sub/deeper/inner.txt"; "top.txt"]);
            testCase.verifyEqual(files.Bytes, [6; 3]);
            testCase.verifyEqual(string(files.ModifiedTime.TimeZone), "UTC");
            testCase.verifyLessThan(abs(files.ModifiedTime(2) - datetime('now', 'TimeZone', 'UTC')), minutes(5));
        end

        function testListLocalFilesOfMissingFolderIsEmpty(testCase)
            files = ebrains.bucket.internal.listLocalFiles(fullfile(testCase.Folder, "missing"));
            testCase.verifyEqual(height(files), 0);
        end

        %% listRemoteFiles
        function testListRemoteFilesStripsPrefixAndLeavesOutFolders(testCase)
            addListing(testCase.Client, makeObjects( ...
                ["set/a.txt", "set/sub", "set/sub/b.txt", "set/marker/"], [3, 0, 5, 0], ...
                ["2024-05-03T10:22:33.123456", "", "2024-05-03T10:22:33Z", ""], ...
                ["ABCDEF", "", "1234-2", ""]));

            files = ebrains.bucket.internal.listRemoteFiles("my-bucket", "set/", testCase.Client);

            testCase.Client.verifyRequestURL(2, 'prefix=set');
            testCase.verifyEqual(files.Path, ["a.txt"; "sub/b.txt"]);
            testCase.verifyEqual(files.Bytes, [3; 5]);
            testCase.verifyEqual(files.ModifiedTime, ...
                repmat(datetime(2024, 5, 3, 10, 22, 33, 'TimeZone', 'UTC'), 2, 1));
            testCase.verifyEqual(files.Hash, ["abcdef"; ""], ...
                'The checksum of a multipart upload is not one of the content.');
        end

        function testListRemoteFilesLeavesOutNamesThatEscapeTheFolder(testCase)
            addListing(testCase.Client, makeObjects( ...
                ["../evil.txt", "sub/../../evil.sh", "back\slash.txt", "a//b.txt", "ok.txt", "sub/ok.txt"], ...
                [1, 1, 1, 1, 1, 1]));

            files = testCase.verifyWarning( ...
                @() ebrains.bucket.internal.listRemoteFiles("my-bucket", "", testCase.Client), ...
                'EBRAINS:Bucket:UnsafeObjectName');

            testCase.verifyEqual(files.Path, ["ok.txt"; "sub/ok.txt"]);
        end

        function testListRemoteFilesReadsTimesWithOffsets(testCase)
            addListing(testCase.Client, makeObjects(["a.txt", "b.txt", "c.txt", "d.txt"], [1, 1, 1, 1], ...
                ["2024-05-03T12:22:33+02:00", "2024-05-03T12:22:33.5+0200", "2024-05-03T10:22:33Z", "not a time"]));

            files = ebrains.bucket.internal.listRemoteFiles("my-bucket", "", testCase.Client);

            expected = datetime(2024, 5, 3, 10, 22, 33, 'TimeZone', 'UTC');
            testCase.verifyEqual(files.ModifiedTime(1:3), repmat(expected, 3, 1));
            testCase.verifyTrue(isnat(files.ModifiedTime(4)));
        end

        function testListRemoteFilesDropsChecksumOfLargeObject(testCase)
            % An object above 5 GiB is held as segments behind a manifest,
            % whose checksum is not one of the content.
            addListing(testCase.Client, makeObjects(["big.bin", "small.bin"], [6 * 1024^3, 1], ...
                ["", ""], ["abcdef", "abcdef"]));

            files = ebrains.bucket.internal.listRemoteFiles("my-bucket", "", testCase.Client);

            testCase.verifyEqual(files.Hash, [""; "abcdef"]);
        end

        function testListRemoteFilesOfEmptyBucket(testCase)
            addListing(testCase.Client, makeObjects(string.empty));

            files = ebrains.bucket.internal.listRemoteFiles("my-bucket", "", testCase.Client);

            testCase.verifyEqual(height(files), 0);
        end

        %% computeMd5
        function testComputeMd5OfKnownContent(testCase)
            filePath = fullfile(testCase.Folder, "abc.txt");
            writeFile(filePath, "abc");

            hash = ebrains.bucket.internal.computeMd5(filePath);

            testCase.verifyEqual(hash, "900150983cd24fb0d6963f7d28e17f72");
        end

        %% syncToBucket
        function testSyncToBucketUploadsNewAndChangedFiles(testCase)
            writeFile(fullfile(testCase.Folder, "new.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "sub", "grown.txt"), "abcdef");
            writeFile(fullfile(testCase.Folder, "same.txt"), "abc");
            % The objects were uploaded after the local files were written
            future = "2100-01-01T00:00:00";
            addListing(testCase.Client, makeObjects( ...
                ["results/sub/grown.txt", "results/same.txt"], [3, 3], [future, future]));
            addUploadUrls(testCase.Client, 2);
            [uploader, getUploads] = recordingUploader();

            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Prefix="/results", Uploader=uploader, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, ["new.txt"; "same.txt"; "sub/grown.txt"]);
            testCase.verifyEqual(actions.Action, ["upload"; "none"; "upload"]);
            testCase.verifyEqual(actions.Status, ["done"; ""; "done"]);
            testCase.Client.verifyRequestURL(3, '/buckets/my-bucket/results/new.txt');
            testCase.Client.verifyRequestURL(4, '/buckets/my-bucket/results/sub/grown.txt');
            uploads = getUploads();
            testCase.verifyEqual(uploads, ...
                [fullfile(testCase.Folder, "new.txt"); fullfile(testCase.Folder, "sub", "grown.txt")]);
        end

        function testSyncToBucketUploadsFileChangedAfterUpload(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            addListing(testCase.Client, makeObjects("a.txt", 3, "2000-01-01T00:00:00"));
            addUploadUrls(testCase.Client, 1);

            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Uploader=recordingUploader(), Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Reason, "newer");
            testCase.verifyEqual(actions.Status, "done");
        end

        function testSyncToBucketDryRunChangesNothing(testCase)
            writeFile(fullfile(testCase.Folder, "new.txt"), "abc");
            addListing(testCase.Client, makeObjects("extra.txt", 1));

            output = evalc(['actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ' ...
                'Delete=true, DryRun=true, Client=testCase.Client);']);

            testCase.verifyEqual(testCase.Client.getRequestCount(), 2, ...
                'Only the listing may be requested.');
            testCase.verifyEqual(actions.Status, ["planned"; "planned"]); %#ok<NODEF> assigned by evalc
            testCase.verifySubstring(output, '[DryRun] Delete extra.txt');
            testCase.verifySubstring(output, '[DryRun] Upload new.txt');
        end

        function testSyncToBucketDryRunShowsARefusalInsteadOfStopping(testCase)
            writeFile(fullfile(testCase.Folder, "new.txt"), "abc");
            addListing(testCase.Client, makeObjects(["x.txt", "y.txt"], [1, 1]));

            output = evalc(['actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ' ...
                'Delete=true, MaxDelete=1, DryRun=true, Client=testCase.Client);']);

            testCase.verifyEqual(actions.Status, ["planned"; "skipped"; "skipped"]); %#ok<NODEF> assigned by evalc
            testCase.verifySubstring(char(actions.Message(2)), 'more than MaxDelete (1)');
            testCase.verifySubstring(output, 'A real run would stop before changing anything');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end

        function testSyncToBucketWarnsWhenTheListingHasNoTimes(testCase)
            % Without times, the default comparison cannot see a changed
            % file of the same size, which must not pass in silence.
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            addListing(testCase.Client, makeObjects("a.txt", 3));

            actions = testCase.verifyWarning(@() ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Client=testCase.Client, Verbose=false), 'EBRAINS:Bucket:Sync:NoRemoteTimes');

            testCase.verifyEqual(actions.Reason, "unchanged");
        end

        function testSyncToBucketDeletesExtraneousObjectsWhenAsked(testCase)
            writeFile(fullfile(testCase.Folder, "keep.txt"), "abc");
            addListing(testCase.Client, makeObjects( ...
                ["data/keep.txt", "data/extra.txt"], [3, 1], ["2100-01-01T00:00:00", ""]));
            testCase.Client.addResponse('OK', struct());

            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Prefix="data/", Delete=true, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Action, ["delete"; "none"]);
            testCase.verifyEqual(actions.Status, ["done"; ""]);
            testCase.Client.verifyRequestMethod(3, 'DELETE');
            testCase.Client.verifyRequestURL(3, '/buckets/my-bucket/data/extra.txt');
        end

        function testSyncToBucketKeepsExtraneousObjectsByDefault(testCase)
            writeFile(fullfile(testCase.Folder, "keep.txt"), "abc");
            addListing(testCase.Client, makeObjects( ...
                ["keep.txt", "extra.txt"], [3, 1], ["2100-01-01T00:00:00", ""]));

            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Action, ["none"; "none"]);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end

        function testSyncToBucketLeavesExcludedFilesAlone(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "scratch.tmp"), "abc");
            addListing(testCase.Client, makeObjects( ...
                ["a.txt", "remote.tmp"], [3, 1], ["2100-01-01T00:00:00", ""]));

            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Exclude="*.tmp", Delete=true, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, "a.txt");
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end

        function testSyncToBucketRefusesToEmptyBucketFromEmptyFolder(testCase)
            addListing(testCase.Client, makeObjects(["a.txt", "b.txt"], [1, 1]));

            testCase.verifyError(@() ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Delete=true, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:EmptySource');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end

        function testSyncToBucketStopsBeforeMoreDeletionsThanAllowed(testCase)
            writeFile(fullfile(testCase.Folder, "new.txt"), "abc");
            addListing(testCase.Client, makeObjects(["x.txt", "y.txt"], [1, 1]));

            testCase.verifyError(@() ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Delete=true, MaxDelete=1, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:TooManyDeletions');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2, ...
                'Nothing may be uploaded before the check.');
        end

        function testSyncToBucketFailedUploadHoldsBackDeletions(testCase)
            writeFile(fullfile(testCase.Folder, "bad.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "good.txt"), "abc");
            addListing(testCase.Client, makeObjects("extra.txt", 1));
            addUploadUrls(testCase.Client, 2);
            refused = matlab.net.http.ResponseMessage(matlab.net.http.StatusLine("HTTP/1.1 403 Forbidden"), [], ...
                matlab.net.http.MessageBody('AccessDenied'));
            accepted = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK);
            uploader = @(source, varargin) deal(~endsWith(source, "bad.txt"), ...
                ifThen(endsWith(source, "bad.txt"), refused, accepted));

            testCase.verifyWarning(@() ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Delete=true, Uploader=uploader, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:Incomplete');

            % The failure is in the table, and the extraneous object is kept
            testCase.verifyEqual(testCase.Client.getRequestCount(), 4, 'No DELETE may be sent.');
            testCase.Client.reset();
            addListing(testCase.Client, makeObjects("extra.txt", 1));
            addUploadUrls(testCase.Client, 2);
            warningState = warning('off', 'EBRAINS:Bucket:Sync:Incomplete');
            testCase.addTeardown(@() warning(warningState));
            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Delete=true, Uploader=uploader, Client=testCase.Client, Verbose=false);
            testCase.verifyEqual(actions.Path, ["bad.txt"; "extra.txt"; "good.txt"]);
            testCase.verifyEqual(actions.Status, ["failed"; "skipped"; "done"]);
            testCase.verifySubstring(char(actions.Message(1)), '403 Forbidden');
        end

        function testSyncToBucketByChecksumUploadsChangedContentOnly(testCase)
            writeFile(fullfile(testCase.Folder, "same.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "edited.txt"), "xyz");
            % Uploaded before the files were written, so only the checksum
            % can tell that same.txt is unchanged
            past = "2000-01-01T00:00:00";
            md5OfAbc = "900150983cd24fb0d6963f7d28e17f72";
            addListing(testCase.Client, makeObjects(["same.txt", "edited.txt"], [3, 3], ...
                [past, past], [md5OfAbc, md5OfAbc]));
            addUploadUrls(testCase.Client, 1);

            actions = ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ...
                Comparison="Checksum", Uploader=recordingUploader(), ...
                Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, ["edited.txt"; "same.txt"]);
            testCase.verifyEqual(actions.Reason, ["checksum"; "unchanged"]);
        end

        function testSyncToBucketPrintsPlanAndProgress(testCase)
            writeFile(fullfile(testCase.Folder, "new.txt"), "abc");
            addListing(testCase.Client, makeObjects("extra.txt", 1));
            addUploadUrls(testCase.Client, 1);
            uploader = recordingUploader(); %#ok<NASGU> read by evalc below

            output = evalc(['ebrains.bucket.syncToBucket(testCase.Folder, "my-bucket", ' ...
                'Uploader=uploader, Client=testCase.Client)']);

            testCase.verifySubstring(output, '1 file(s) to upload (3.00 bytes), 0 to delete, 0 unchanged.');
            testCase.verifySubstring(output, 'Use Delete=true');
            testCase.verifySubstring(output, '[1/1] Upload new.txt (3.00 bytes)');
            testCase.verifySubstring(output, 'Done: 1 copied, 0 deleted, 0 failed.');
        end

        %% syncFromBucket
        function testSyncFromBucketDownloadsIntoNewFolder(testCase)
            target = fullfile(testCase.Folder, "mirror");
            addListing(testCase.Client, makeObjects( ...
                ["set/a.txt", "set/sub/b.txt"], [3, 3]));
            addDownloadUrls(testCase.Client, 2);

            actions = ebrains.bucket.syncFromBucket("my-bucket", target, Prefix="set", ...
                Downloader=@writeAbc, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Action, ["download"; "download"]);
            testCase.verifyEqual(actions.Status, ["done"; "done"]);
            testCase.verifyEqual(fileread(fullfile(target, "sub", "b.txt")), 'abc');
            testCase.Client.verifyRequestURL(3, '/buckets/my-bucket/set/a.txt');
            testCase.Client.verifyRequestURL(4, '/buckets/my-bucket/set/sub/b.txt');
        end

        function testSyncFromBucketSkipsFilesDownloadedAfterUpload(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            addListing(testCase.Client, makeObjects("a.txt", 3, "2000-01-01T00:00:00"));

            actions = ebrains.bucket.syncFromBucket("my-bucket", testCase.Folder, ...
                Downloader=@writeAbc, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Action, "none");
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end

        function testSyncFromBucketDeletesExtraneousLocalFilesWhenAsked(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "sub", "extra.txt"), "abc");
            addListing(testCase.Client, makeObjects("a.txt", 3, "2000-01-01T00:00:00"));

            actions = ebrains.bucket.syncFromBucket("my-bucket", testCase.Folder, ...
                Delete=true, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, ["a.txt"; "sub/extra.txt"]);
            testCase.verifyEqual(actions.Status, [""; "done"]);
            testCase.verifyFalse(isfile(fullfile(testCase.Folder, "sub", "extra.txt")));
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "a.txt")));
        end

        function testSyncFromBucketReportsDownloadOfWrongSizeAndKeepsTheFile(testCase)
            % The object was replaced between the listing and the download.
            % The local file must be as it was, and the temporary file of
            % the download must not remain next to it.
            writeFile(fullfile(testCase.Folder, "a.txt"), "previous");
            addListing(testCase.Client, makeObjects("a.txt", 10, "2100-01-01T00:00:00"));
            addDownloadUrls(testCase.Client, 1);
            warningState = warning('off', 'EBRAINS:Bucket:Sync:Incomplete');
            testCase.addTeardown(@() warning(warningState));

            actions = ebrains.bucket.syncFromBucket("my-bucket", testCase.Folder, ...
                Downloader=@writeAbc, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Status, "failed");
            testCase.verifySubstring(char(actions.Message), 'has 3 bytes, where the object has 10');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a.txt")), 'previous');
            testCase.verifyEqual(listFileNames(testCase.Folder), "a.txt");
        end

        function testSyncFromBucketRefusesToDeleteANameWithWildcards(testCase)
            % delete expands "*" and "?" to other files, so such a file is
            % left and reported rather than risk the others.
            testCase.assumeFalse(ispc, 'Windows does not allow "*" in a file name.');
            writeFile(fullfile(testCase.Folder, "notes*.md"), "abc");
            writeFile(fullfile(testCase.Folder, "notes-final.md"), "abc");
            addListing(testCase.Client, makeObjects("notes-final.md", 3, "2000-01-01T00:00:00"));
            warningState = warning('off', 'EBRAINS:Bucket:Sync:Incomplete');
            testCase.addTeardown(@() warning(warningState));

            actions = ebrains.bucket.syncFromBucket("my-bucket", testCase.Folder, ...
                Delete=true, Client=testCase.Client, Verbose=false);

            testCase.verifyEqual(actions.Path, ["notes*.md"; "notes-final.md"]);
            testCase.verifyEqual(actions.Status(1), "failed");
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "notes-final.md")));
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "notes*.md")));
        end

        function testSyncFromBucketRefusesToEmptyFolderFromEmptyPrefix(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            addListing(testCase.Client, makeObjects(string.empty));

            testCase.verifyError(@() ebrains.bucket.syncFromBucket("my-bucket", testCase.Folder, ...
                Prefix="typo", Delete=true, Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:EmptySource');
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "a.txt")));
        end

        function testSyncFromBucketRejectsFileAsTarget(testCase)
            filePath = fullfile(testCase.Folder, "a.txt");
            writeFile(filePath, "abc");

            testCase.verifyError(@() ebrains.bucket.syncFromBucket("my-bucket", filePath, ...
                Client=testCase.Client, Verbose=false), ...
                'EBRAINS:Bucket:Sync:TargetIsFile');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end
    end
end

function files = makeFiles(paths, bytes, modifiedTimes, hashes)
% makeFiles - File table with unknown times and checksums unless given
    arguments
        paths string
        bytes double
        modifiedTimes datetime = NaT(numel(paths), 1)
        hashes string = strings(numel(paths), 1)
    end
    files = ebrains.bucket.internal.makeFileTable(paths, bytes, modifiedTimes, hashes);
end

function page = makeObjects(names, bytes, lastModified, hashes)
% makeObjects - Listing page with the fields the Data Proxy reports per object
%
%   An empty JSON array decodes to [], and the page keeps that shape.

    arguments
        names string
        bytes double = zeros(size(names))
        lastModified string = repmat("", size(names))
        hashes string = repmat("", size(names))
    end

    if isempty(names)
        page = struct('objects', []);
        return
    end
    page = struct('objects', struct( ...
        'name', cellstr(reshape(names, [], 1)), ...
        'bytes', num2cell(reshape(bytes, [], 1)), ...
        'last_modified', cellstr(reshape(lastModified, [], 1)), ...
        'hash', cellstr(reshape(hashes, [], 1)), ...
        'content_type', 'application/octet-stream'));
end

function addListing(client, page)
% addListing - Queue the stat and the single page of a listing
    client.addResponse('OK', struct('name', 'my-bucket', ...
        'objects_count', numel(page.objects), 'bytes', 0));
    client.addResponse('OK', page);
end

function addUploadUrls(client, count)
    for i = 1:count
        client.addResponse('OK', struct('url', sprintf('https://store.example.org/upload?sig=%d', i)));
    end
end

function addDownloadUrls(client, count)
    for i = 1:count
        client.addResponse('OK', struct('url', sprintf('https://store.example.org/download?sig=%d', i)));
    end
end

function [uploader, getUploads] = recordingUploader()
% recordingUploader - Uploader that accepts every file and records which
%
%   The record is a containers.Map, a handle, so the anonymous functions
%   share it.
    record = containers.Map('KeyType', 'double', 'ValueType', 'any');
    uploader = @(source, varargin) recordUpload(record, source);
    getUploads = @() reshape(string(values(record)), [], 1);
end

function [wasSuccess, response] = recordUpload(record, source)
    record(record.Count + 1) = string(source);
    wasSuccess = true;
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK);
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
    fwrite(fileID, char(content));
    fclose(fileID);
end

function fileNames = listFileNames(folder)
% listFileNames - Names of the files directly in a folder, as a string row
    listing = dir(folder);
    fileNames = string({listing(~[listing.isdir]).name});
end

function value = ifThen(condition, valueIfTrue, valueIfFalse)
    if condition
        value = valueIfTrue;
    else
        value = valueIfFalse;
    end
end
