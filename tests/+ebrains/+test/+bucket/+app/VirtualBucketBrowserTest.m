classdef VirtualBucketBrowserTest < matlab.unittest.TestCase
    % VirtualBucketBrowserTest - Tests of the virtual bucket browser with its page
    %
    % The browser runs with a MockBucketsClient and a stand-in for the
    % downloader, so no request reaches the Data Proxy. The requests of
    % the page are sent to the callback of its uihtml component, as the
    % page sends them. The browser is opened through openApp, which
    % replaces every dialog: a Confirmer that records the question and
    % refuses, a FolderChooser that answers with ChosenFolder, an Alerter
    % that records the alert and a FakeProgressDialog. A confirmation or
    % folder dialog would wait for a user, and on some releases uialert
    % and uiprogressdlg never return on a virtual display. The window is
    % hidden, so no test shows one. The registry of virtual buckets is
    % kept in the folder of each test.

    properties
        Client ebrains.mocks.MockBucketsClient
        Folder string
        App ebrains.bucket.app.VirtualBucketBrowser

        % OpenedURL - Addresses the browser asked its opener to show
        OpenedURL (1,:) string = string.empty(1, 0)

        % Confirmations - Titles and messages of the confirmations the browser asked for, one row each
        Confirmations (:,2) string = strings(0, 2)

        % Alerts - Titles and messages of the alerts the browser showed, one row each
        Alerts (:,2) string = strings(0, 2)

        % ChosenFolder - What the folder chooser answers; empty for a cancelled dialog
        ChosenFolder string = string.empty

        % ChooserTitles - Titles of the folder dialogs the browser asked for
        ChooserTitles (1,:) string = string.empty(1, 0)
    end

    methods (TestClassSetup)
        function requireRelease(testCase)
            % The browser refuses to open before R2023a, which the toolbox
            % supports otherwise (EBRAINS:Bucket:UnsupportedRelease)
            testCase.assumeFalse(isMATLABReleaseOlderThan("R2023a"), ...
                "The browser needs MATLAB R2023a or later.")
        end

        function requireDisplay(testCase)
            try
                figureHandle = uifigure(Visible="off");
                delete(figureHandle)
            catch
                testCase.assumeFail("The browser needs a display to create a uifigure.")
            end
        end
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            testCase.Client = ebrains.mocks.MockBucketsClient();
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = string(folderFixture.Folder);
            % The browser records the folders it opens in the registry of
            % the user, which the test keeps in a folder of its own, apart
            % from the folders it opens as virtual buckets
            configFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.applyFixture(ebrains.test.fixtures.EnvironmentVariableFixture( ...
                "EBRAINS_BUCKET_SYNC_CONFIG_DIR", fullfile(configFixture.Folder, "config")));
        end
    end

    methods (TestMethodTeardown)
        function closeApp(testCase)
            if ~isempty(testCase.App) && isvalid(testCase.App)
                delete(testCase.App)
            end
        end
    end

    methods (Test)
        function testOpenJudgesFilesBySizeWithoutListing(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "sub", "b.txt"), "");

            testCase.openApp(testCase.Folder);

            testCase.verifyEqual(testCase.App.Files.Path, ["a.txt"; "sub/b.txt"]);
            testCase.verifyEqual(testCase.App.Files.State, ["downloaded"; "online_only"]);
            testCase.verifyFalse(testCase.App.IsListed);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testTransferLeftoversAreNotShown(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            % Left behind by a download, and by a multipart upload of the
            % ebrains-bucket-sync package, that a killed process did not finish
            writeFile(fullfile(testCase.Folder, "a.txt.k3x9.sync-part"), "partial");
            writeFile(fullfile(testCase.Folder, "sub", "big.dat.multipart_manifest.json"), "{}");

            testCase.openApp(testCase.Folder);

            testCase.verifyEqual(testCase.App.Files.Path, "a.txt");
        end

        function testNewFolderIsFilledFromListing(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["a.txt", "sub/b.txt"], [3, 3]);

            testCase.openApp(target);

            testCase.verifyEqual(testCase.App.Files.State, ["online_only"; "online_only"]);
            testCase.verifyEqual(dir(fullfile(target, "sub", "b.txt")).bytes, 0);
            testCase.verifyTrue(testCase.App.IsListed);
        end

        function testUpdateAddsPlaceholdersAndComparesWithBucket(testCase)
            writeFile(fullfile(testCase.Folder, "changed.txt"), "abcdef");
            writeFile(fullfile(testCase.Folder, "extra.txt"), "abc");
            testCase.openApp(testCase.Folder);
            addListing(testCase.Client, ["changed.txt", "new.txt"], [3, 3]);

            sendPageEvent("update")

            files = testCase.App.Files;
            testCase.verifyEqual(files.Path, ["changed.txt"; "extra.txt"; "new.txt"]);
            testCase.verifyEqual(files.State, ["differs"; "local_only"; "online_only"]);
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "new.txt")));
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "extra.txt")), 'abc', ...
                'A file that the bucket does not have is kept.');
        end

        function testDownloadFillsPlaceholder(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["a.txt", "sub/b.txt"], [3, 3]);
            testCase.openApp(target);
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));

            sendPageEvent("download", "sub/b.txt")

            testCase.verifyEqual(fileread(fullfile(target, "sub", "b.txt")), 'abc');
            testCase.verifyEqual(testCase.App.Files.State, ["online_only"; "downloaded"]);
            testCase.Client.verifyRequestURL(4, '/buckets/my-bucket/sub/b.txt');
        end

        function testDownloadOfDownloadedFilesSaysSo(testCase)
            target = testCase.openWithDownloadedFile();

            sendPageEvent("download", "a.txt")

            testCase.verifyEqual(testCase.Alerts, ["Nothing to download", "The selected files are downloaded already."]);
            testCase.verifyEqual(fileread(fullfile(target, "a.txt")), 'abc');
        end

        function testDownloadGoesOnPastAFileThatFails(testCase)
            % Before a listing, an empty file that is no object counts as
            % a placeholder, and its failed download must not stop the rest
            writeFile(fullfile(testCase.Folder, "pkg", "__init__.py"), "");
            writeFile(fullfile(testCase.Folder, "pkg", "data.bin"), "");
            testCase.openApp(testCase.Folder);
            testCase.Client.addResponse('NotFound', "Object not found");
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));

            sendPageEvent("download", ["pkg/__init__.py", "pkg/data.bin"])

            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "pkg", "data.bin")), 'abc');
            testCase.verifyEqual(testCase.App.Files.State, ["online_only"; "downloaded"]);
        end

        function testOnlineOnlyEmptiesFileThatMatchesItsObject(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            giveTimeOfListedObjects(fullfile(testCase.Folder, "a.txt"));
            testCase.openApp(testCase.Folder);
            addListing(testCase.Client, "a.txt", 3);
            sendPageEvent("update")

            sendPageEvent("onlineOnly", "a.txt")

            testCase.verifyEqual(dir(fullfile(testCase.Folder, "a.txt")).bytes, 0);
            testCase.verifyEqual(testCase.App.Files.State, "online_only");
        end

        function testPathsAreRelativeToPrefix(testCase)
            % The folder holds the objects of the prefix folder, as for
            % ebrains.bucket.sync.fromBucket, and a download asks for the
            % object by its full name.
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["set/a.txt", "set/sub/b.txt"], [3, 3]);
            testCase.openApp(target, Prefix="set");
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));

            sendPageEvent("download", "sub/b.txt")

            testCase.verifyEqual(testCase.App.Files.Path, ["a.txt"; "sub/b.txt"]);
            testCase.verifyEqual(testCase.App.Files.State, ["online_only"; "downloaded"]);
            testCase.Client.verifyRequestURL(4, '/buckets/my-bucket/set/sub/b.txt');
        end
    end

    methods (Test) % The .ebrains folder
        function testReopeningComparesWithTheSavedListing(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["a.txt", "b.txt"], [3, 3]);
            testCase.openApp(target);
            writeFile(fullfile(target, "b.txt"), "abcd");
            delete(testCase.App)
            nRequests = testCase.Client.getRequestCount();

            testCase.openApp(target, BucketName=string.empty);

            testCase.verifyEqual(testCase.App.BucketName, "my-bucket");
            testCase.verifyTrue(testCase.App.IsListed);
            testCase.verifyFalse(isnat(testCase.App.ListedTime));
            testCase.verifyEqual(testCase.App.Files.State, ["online_only"; "differs"]);
            testCase.verifyEqual(testCase.Client.getRequestCount(), nRequests, ...
                'Reopening a virtual bucket does not list the bucket.');
        end

        function testTransferLeftoverOfTheManifestIsNotShown(testCase)
            % The manifest is written by whichever tool listed the bucket
            % last, and need not leave out an object named like the file of
            % an interrupted transfer, as a listing of this toolbox does
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            ebrains.bucket.internal.metadata.writeBucketInfo(testCase.Folder, "my-bucket", "", ...
                datetime(2000, 1, 1, TimeZone="UTC"));
            ebrains.bucket.internal.metadata.writeManifest(testCase.Folder, ...
                ebrains.bucket.sync.internal.makeFileTable(["a.txt"; "old.dat.z1.sync-part"], [3; 1]));

            testCase.openApp(testCase.Folder);

            testCase.verifyTrue(testCase.App.IsListed);
            testCase.verifyEqual(testCase.App.Files.Path, "a.txt");
        end

        function testFolderThatIsNotAVirtualBucketNeedsBucketName(testCase)
            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser(testCase.Folder, ...
                Client=testCase.Client), 'EBRAINS:Bucket:NotAVirtualBucket');
        end

        function testExistingFolderBecomesVirtualBucketWithoutListing(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "");

            testCase.openApp(testCase.Folder);

            info = ebrains.bucket.internal.metadata.readBucketInfo(testCase.Folder);
            testCase.verifyEqual(info.BucketName, "my-bucket");
            testCase.verifyTrue(isnat(info.ListedTime));
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testBucketNameWithoutPrefixOpensPrefixedBucket(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, "set/a.txt", 3);
            testCase.openApp(target, Prefix="set");
            delete(testCase.App)

            testCase.openApp(target);

            testCase.verifyEqual(testCase.App.Prefix, "set/");
            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser(target, ...
                BucketName="my-bucket", Prefix="other", Client=testCase.Client), 'EBRAINS:Bucket:OtherBucket');
        end

        function testOpeningAVirtualBucketWritesNothing(testCase)
            % A virtual bucket on a read-only location must open, so the
            % description is only read. The file keeps the old time it is
            % given here.
            testCase.openApp(testCase.Folder);
            delete(testCase.App)
            bucketFile = fullfile(testCase.Folder, ".ebrains", "bucket.json");
            oldTime = datetime(2000, 1, 1, TimeZone="UTC");
            java.io.File(char(bucketFile)).setLastModified(round(posixtime(oldTime) * 1000));

            testCase.openApp(testCase.Folder, BucketName=string.empty);

            modifiedTime = datetime(java.io.File(char(bucketFile)).lastModified() / 1000, ...
                ConvertFrom="posixtime", TimeZone="UTC");
            testCase.verifyEqual(modifiedTime, oldTime);
        end

        function testDownloadGivesFileTheTimeOfItsObject(testCase)
            % A sync to the bucket must not upload the file again, so it
            % gets the time of its object, as a sync from the bucket does.
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, "a.txt", 3);
            testCase.openApp(target);
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));

            sendPageEvent("download", "a.txt")

            fileTime = datetime(java.io.File(char(fullfile(target, "a.txt"))).lastModified() / 1000, ...
                ConvertFrom="posixtime", TimeZone="UTC");
            testCase.verifyEqual(fileTime, datetime(2000, 1, 1, TimeZone="UTC"));
        end

        function testDownloadOfWrongSizeKeepsThePlaceholder(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, "a.txt", 10);
            testCase.openApp(target);
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));

            sendPageEvent("download", "a.txt")

            testCase.verifyEqual(dir(fullfile(target, "a.txt")).bytes, 0);
            testCase.verifyEqual(testCase.App.Files.State, "online_only");
        end

        function testFilesThatDifferOnlyInCaseAreOneFile(testCase)
            assumeCaseInsensitive(testCase);
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["Data.txt", "data.txt"], [3, 3]);
            testCase.openApp(target);
            writeFile(fullfile(target, "data.txt"), "abc");
            giveTimeOfListedObjects(fullfile(target, "data.txt"));

            sendPageEvent("refresh")

            testCase.verifyEqual(testCase.App.Files.Path, "Data.txt", ...
                'Only the first of the objects is shown, under its own name.');
            testCase.verifyEqual(testCase.App.Files.State, "downloaded");
        end

        function testOtherBucketIsRefused(testCase)
            testCase.openApp(testCase.Folder);
            delete(testCase.App)

            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser(testCase.Folder, ...
                BucketName="other-bucket", Client=testCase.Client), 'EBRAINS:Bucket:OtherBucket');
        end

        function testOtherPrefixIsRefusedWithoutBucketName(testCase)
            testCase.openApp(testCase.Folder);
            delete(testCase.App)

            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser(testCase.Folder, ...
                Prefix="other", Client=testCase.Client), 'EBRAINS:Bucket:OtherBucket');
        end

        function testPrefixWithDriveIsRefused(testCase)
            target = fullfile(testCase.Folder, "virtual");

            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser(target, ...
                BucketName="my-bucket", Prefix="C:/set", Client=testCase.Client), ...
                'EBRAINS:Bucket:InvalidPrefix');

            testCase.verifyFalse(isfolder(target), 'The folder is not created for a refused prefix.');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testUpdateDeletesPlaceholderOfRemovedObject(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["a.txt", "gone.txt"], [3, 3]);
            testCase.openApp(target);
            addListing(testCase.Client, "a.txt", 3);

            sendPageEvent("update")

            testCase.verifyFalse(isfile(fullfile(target, "gone.txt")));
            testCase.verifyEqual(testCase.App.Files.Path, "a.txt");
        end

        function testUpdateKeepsPlaceholderWrittenIntoSinceTheLastScan(testCase)
            % The browser scanned the folder when it opened, when gone.txt
            % was an empty placeholder. Data is written into it after that,
            % as a script that saves into the folder does, and the object
            % is removed from the bucket. The update must not delete the
            % file from the stale scan: it holds the only copy of its data.
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["a.txt", "gone.txt"], [3, 3]);
            testCase.openApp(target);
            goneFile = fullfile(target, "gone.txt");
            placeholder = dir(goneFile);
            testCase.assertEqual(placeholder.bytes, 0, "gone.txt starts as an empty placeholder.");
            writeFile(goneFile, "new data");
            addListing(testCase.Client, "a.txt", 3);

            sendPageEvent("update")

            testCase.verifyTrue(isfile(goneFile));
            testCase.verifyEqual(fileread(goneFile), 'new data');
            testCase.verifyEqual(testCase.App.Files.Path, ["a.txt"; "gone.txt"]);
            testCase.verifyEqual(testCase.App.Files.State(testCase.App.Files.Path == "gone.txt"), "local_only");
        end

        function testOnlineOnlyOfEditedFileIsNotSilent(testCase)
            % A file changed in place after its download keeps its size, and
            % is later than its object. It differs, so emptying it asks first.
            target = testCase.openWithDownloadedFile();
            writeFile(fullfile(target, "a.txt"), "xyz");

            testCase.App.refresh()

            testCase.verifyEqual(testCase.App.Files.State, "differs");
        end

        function testOnlineOnlyReadsAFileAgainBeforeJudgingIt(testCase)
            % The file is edited after the last scan, so the table of the
            % browser still says that it is downloaded
            target = testCase.openWithDownloadedFile();
            writeFile(fullfile(target, "a.txt"), "xyz");

            sendPageEvent("onlineOnly", "a.txt")

            testCase.verifyEqual(fileread(fullfile(target, "a.txt")), 'xyz');
            testCase.assertSize(testCase.Confirmations, [1, 2]);
            testCase.verifyEqual(testCase.Confirmations(1, 1), "Make online only?");
            testCase.verifySubstring(testCase.Confirmations(1, 2), "1 of the 1 files differ from the bucket");
            testCase.verifyEqual(testCase.App.Files.State, "differs");
        end

        function testDownloadReadsAFileAgainBeforeJudgingIt(testCase)
            target = testCase.openWithDownloadedFile();
            nRequests = testCase.Client.getRequestCount();
            writeFile(fullfile(target, "a.txt"), "xyz");

            sendPageEvent("download", "a.txt")

            testCase.verifyEqual(fileread(fullfile(target, "a.txt")), 'xyz');
            testCase.assertSize(testCase.Confirmations, [1, 2]);
            testCase.verifyEqual(testCase.Confirmations(1, 1), "Replace local copies?");
            testCase.verifyEqual(testCase.Client.getRequestCount(), nRequests, ...
                'A refused confirmation requests no download.');
        end

        function testDownloadReadsAFileStoredUnderAnotherCase(testCase)
            % The file is stored as data.txt and listed as Data.txt, so its
            % row carries the path of the object. Edited after the last
            % scan, it differs, and downloading it must ask, rather than
            % take it for a placeholder because the stored name has
            % another case.
            assumeCaseInsensitive(testCase);
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, "Data.txt", 3);
            testCase.openApp(target);
            delete(fullfile(target, "Data.txt"))
            writeFile(fullfile(target, "data.txt"), "abc");
            giveTimeOfListedObjects(fullfile(target, "data.txt"));
            sendPageEvent("refresh")
            testCase.assertEqual(testCase.App.Files.Path, "Data.txt");
            testCase.assertEqual(testCase.App.Files.State, "downloaded");
            writeFile(fullfile(target, "data.txt"), "xyz");
            nRequests = testCase.Client.getRequestCount();

            sendPageEvent("download", "Data.txt")

            testCase.verifyEqual(fileread(fullfile(target, "data.txt")), 'xyz');
            testCase.assertSize(testCase.Confirmations, [1, 2]);
            testCase.verifyEqual(testCase.Confirmations(1, 1), "Replace local copies?");
            testCase.verifyEqual(testCase.Client.getRequestCount(), nRequests, ...
                'A refused confirmation requests no download.');
        end

        function testDownloadKeepsAFileEditedWhileItWasDownloaded(testCase)
            % The file is judged before the download and can change while
            % the object is transferred, so it is checked again right
            % before the download replaces it.
            target = fullfile(testCase.Folder, "virtual");
            localFile = fullfile(target, "a.txt");
            addListing(testCase.Client, "a.txt", 3);
            testCase.openApp(target, Downloader=@(file, varargin) editThenWrite(localFile, file));
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));

            sendPageEvent("download", "a.txt")

            testCase.verifyEqual(fileread(localFile), 'xyz');
            testCase.verifyEqual(testCase.App.Files.State, "differs");
        end

        function testOnlineOnlyReadsAFileRestoredWithTheTimeOfItsChecksum(testCase)
            % A file rewritten with the time it had when its checksum was
            % cached looks unchanged to the cache. Making it online only
            % discards it, so the checksum is read again first.
            target = fullfile(testCase.Folder, "virtual");
            localFile = fullfile(target, "a.txt");
            addListing(testCase.Client, "a.txt", 3, "900150983cd24fb0d6963f7d28e17f72"); % MD5 of "abc"
            testCase.openApp(target);
            laterTime = datetime(2000, 1, 1, 1, 0, 0, TimeZone="UTC");
            writeFile(localFile, "abc");
            setFileTime(localFile, laterTime);
            sendPageEvent("refresh")
            testCase.assertEqual(testCase.App.Files.State, "downloaded", ...
                'The checksum, not the time, says that the file is downloaded.');
            writeFile(localFile, "xyz");
            setFileTime(localFile, laterTime);

            sendPageEvent("onlineOnly", "a.txt")

            testCase.verifyEqual(fileread(localFile), 'xyz');
            testCase.assertSize(testCase.Confirmations, [1, 2]);
            testCase.verifyEqual(testCase.App.Files.State, "differs");
        end
    end

    methods (Test) % The page of the bucket
        function testOpenOnlineShowsThePageOfTheBucket(testCase)
            testCase.openApp(testCase.Folder, Opener=@(url) recordURL(testCase, url));

            sendPageEvent("openOnline")

            testCase.verifyEqual(testCase.OpenedURL, "https://wiki.ebrains.eu/bin/view/Collabs/my-bucket/Bucket");
        end

        function testDatasetBucketHasAPageUnderItsName(testCase)
            datasetBucket = "d-3e860b3e-967c-425d-aa68-120451c5fe4b";

            url = ebrains.bucket.internal.buildBucketViewURL(datasetBucket);

            testCase.verifyEqual(url, "https://wiki.ebrains.eu/bin/view/Collabs/" + datasetBucket + "/Bucket");
        end

        function testBucketNameIsEncodedAsOneSegment(testCase)
            url = ebrains.bucket.internal.buildBucketViewURL("odd name/x");

            testCase.verifyEqual(url, "https://wiki.ebrains.eu/bin/view/Collabs/odd%20name%2Fx/Bucket");
        end
    end

    methods (Test) % Progress of a listing
        function testUpdateListsInSmallPages(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, "a.txt", 3);

            testCase.openApp(target);

            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket/stat');
            testCase.Client.verifyRequestURL(3, 'limit=1000');
        end

        function testProgressShowsCountAndTimeLeft(testCase)
            progress = ebrains.bucket.app.internal.ListingProgress(ebrains.mocks.FakeProgressDialog([]), 20481, true);

            progress.update(4000)

            testCase.verifySubstring(char(progress.Dialog.Message), 'Listed 4,000 of about 20,481 objects.');
            testCase.verifySubstring(char(progress.Dialog.Message), 'left.');
            testCase.verifyEqual(progress.Dialog.Value, 4000 / 20481, AbsTol=1e-12);
        end

        function testProgressOfFolderShowsNoFraction(testCase)
            progress = ebrains.bucket.app.internal.ListingProgress(ebrains.mocks.FakeProgressDialog([]), 20481, false);

            progress.update(1000)

            testCase.verifyEqual(progress.Dialog.Indeterminate, "on");
            testCase.verifySubstring(char(progress.Dialog.Message), '1,000 listed so far');
        end

        function testCancelStopsTheListing(testCase)
            dialog = ebrains.mocks.FakeProgressDialog([]);
            dialog.CancelRequested = true;
            progress = ebrains.bucket.app.internal.ListingProgress(dialog, 10, true);

            testCase.verifyError(@() progress.update(5), 'EBRAINS:Bucket:ListingCancelled');
        end
    end

    methods (Test)
        %% List of virtual buckets
        function testOpeningWithoutAFolderShowsTheRecordedFolders(testCase)
            recorded = testCase.makeVirtualBucketFolder("recorded", "other-bucket");
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.recordOpen(registry, recorded, "other-bucket", "", ...
                datetime(2024, 1, 2, TimeZone="UTC")));

            testCase.openList();
            sendListRequest("ready")

            testCase.verifyEqual(testCase.App.LocalFolder, "");
            testCase.verifyEqual(testCase.App.ListedBuckets.Path, recorded);
            testCase.verifyEqual(testCase.App.ListedBuckets.Bucket, "other-bucket");
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
            testCase.verifyNotEmpty(findall(groot, "Type", "figure", "Name", "Virtual buckets"));
        end

        function testListShowsTheVirtualBucketsBelowTheRoot(testCase)
            rootFolder = fullfile(testCase.Folder, "root");
            scanned = testCase.makeVirtualBucketFolder(fullfile("root", "d-1"), "d-1");
            mkdir(fullfile(rootFolder, "notes"))
            ebrains.bucket.setVirtualBucketRoot(rootFolder)

            testCase.openList();

            testCase.verifyEqual(testCase.App.ListedBuckets.Path, scanned);
            testCase.verifyEqual(testCase.App.ListedBuckets.Exists, true);
        end

        function testOpeningABucketFromTheListRecordsIt(testCase)
            folder = testCase.makeVirtualBucketFolder("vb", "my-bucket");
            writeFile(fullfile(folder, "a.txt"), "abc");
            testCase.openList();

            sendListRequest("openBucket", struct("path", folder))

            testCase.verifyEqual(testCase.App.LocalFolder, folder);
            testCase.verifyEqual(testCase.App.BucketName, "my-bucket");
            testCase.verifyEqual(testCase.App.Files.Path, "a.txt");
            testCase.verifyNotEmpty(findall(groot, "Type", "figure", "Name", "Virtual bucket - my-bucket"));
            folders = ebrains.bucket.internal.registry.readRegistry().Folders;
            testCase.verifyEqual(folders.Path, folder);
            testCase.verifyFalse(isnat(folders.LastOpened));
        end

        function testNewBucketFromTheListCreatesAndFillsTheFolder(testCase)
            target = fullfile(testCase.Folder, "new");
            addListing(testCase.Client, ["a.txt", "sub/b.txt"], [3, 3]);
            testCase.openList();

            sendListRequest("newBucket", struct("bucket", "my-bucket", "prefix", "", "folder", target))

            testCase.verifyEqual(testCase.App.Files.State, ["online_only"; "online_only"]);
            testCase.verifyEqual(dir(fullfile(target, "sub", "b.txt")).bytes, 0);
            folders = ebrains.bucket.internal.registry.readRegistry().Folders;
            testCase.verifyEqual(folders.Path, ebrains.bucket.internal.absoluteFolderPath(target));
            testCase.verifyEqual(folders.Bucket, "my-bucket");
        end

        function testNewBucketOfAnotherBucketThanTheFolderIsRefused(testCase)
            folder = testCase.makeVirtualBucketFolder("vb", "other-bucket");
            testCase.openList();

            sendListRequest("newBucket", struct("bucket", "my-bucket", "prefix", "", "folder", folder))

            testCase.verifyEqual(testCase.App.LocalFolder, "", "The list stays, and the page is told why.");
            testCase.verifyEqual(ebrains.bucket.internal.metadata.readBucketInfo(folder).BucketName, "other-bucket");
            testCase.verifyEmpty(ebrains.bucket.internal.registry.readRegistry().Folders);
        end

        function testNewBucketNeedsAnAbsoluteFolder(testCase)
            testCase.openList();

            sendListRequest("newBucket", struct("bucket", "my-bucket", "prefix", "", "folder", "relative"))

            testCase.verifyEqual(testCase.App.LocalFolder, "");
            testCase.verifyFalse(isfolder("relative"));
            testCase.verifyEmpty(ebrains.bucket.internal.registry.readRegistry().Folders);
        end

        function testOpeningAFolderThatIsNotInTheListLeavesIt(testCase)
            testCase.openList();

            sendListRequest("openBucket", struct("path", fullfile(testCase.Folder, "missing")))

            testCase.verifyEqual(testCase.App.LocalFolder, "");
            testCase.verifyEmpty(ebrains.bucket.internal.registry.readRegistry().Folders);
        end

        function testAFolderThatFailsAfterValidationLeavesTheList(testCase)
            folder = testCase.makeVirtualBucketFolder("vb", "my-bucket");
            writeFile(fullfile(folder, ".ebrains", "manifest.csv"), "not,a,manifest");
            testCase.openList();

            sendListRequest("openBucket", struct("path", folder))

            testCase.verifyEqual(testCase.App.LocalFolder, "", "The manifest is refused, and the browser is as it was.");
            testCase.verifyEqual(testCase.App.BucketName, "");
            testCase.verifyNotEmpty(findall(groot, "Type", "figure", "Name", "Virtual buckets"));
        end

        function testBucketViewCarriesTheLabelOfTheBucket(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.setLabel(registry, "my-bucket", "Mouse V1"));

            testCase.openApp(testCase.Folder);

            testCase.verifyEqual(testCase.App.Label, "Mouse V1");
            sendPageEvent("showList")
            testCase.verifyEqual(testCase.App.Label, "");
        end

        function testAnUnreadableRegistryGivesAnEmptyList(testCase)
            registryFile = ebrains.bucket.internal.registry.registryPath();
            writeFile(registryFile, "{");

            testCase.openList();

            testCase.verifyEmpty(testCase.App.ListedBuckets);
            sendListRequest("setLabel", struct("bucket", "my-bucket", "label", "x"))
            testCase.verifyEqual(fileread(registryFile), '{', "A registry that cannot be read is not written over.");
        end

        function testBucketsEventWritesTheRowsAsAList(testCase)
            noRows = ebrains.bucket.listVirtualBuckets();
            testCase.assertEmpty(noRows);
            folder = testCase.makeVirtualBucketFolder("vb", "my-bucket");
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.recordOpen(registry, folder, "my-bucket", "", ...
                datetime(2024, 1, 2, TimeZone="UTC")));
            oneRow = ebrains.bucket.listVirtualBuckets();

            textOfNone = ebrains.bucket.app.VirtualBucketBrowser.bucketsEventData(noRows, "");
            textOfOne = ebrains.bucket.app.VirtualBucketBrowser.bucketsEventData(oneRow, "/root");

            testCase.verifySubstring(textOfNone, '"rows":[]');
            testCase.verifySubstring(textOfOne, '"rows":[{"path":');
            testCase.verifySubstring(textOfOne, '"exists":true}]');
            testCase.verifySubstring(textOfOne, '"root":"/root"');
        end

        function testBackToTheListClosesTheBucket(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            testCase.openApp(testCase.Folder);

            sendPageEvent("showList")

            testCase.verifyEqual(testCase.App.LocalFolder, "");
            testCase.verifyEqual(testCase.App.BucketName, "");
            testCase.verifyEmpty(testCase.App.Files);
            testCase.verifyEqual(testCase.App.ListedBuckets.Bucket, "my-bucket", ...
                "The folder that was open is in the list, since opening it recorded it.");
            testCase.verifyNotEmpty(findall(groot, "Type", "figure", "Name", "Virtual buckets"));
            testCase.verifyError(@() testCase.App.updateFromBucket(), 'EBRAINS:Bucket:NoBucketOpen');
        end

        function testOpeningAFolderRecordsItInTheList(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            before = datetime("now", TimeZone="UTC");

            testCase.openApp(testCase.Folder);

            folders = ebrains.bucket.internal.registry.readRegistry().Folders;
            testCase.verifyEqual(folders.Path, testCase.App.LocalFolder);
            testCase.verifyEqual(folders.Bucket, "my-bucket");
            testCase.verifyGreaterThanOrEqual(folders.LastOpened, before - seconds(1));
        end

        function testLabelPinAndRemoveChangeTheList(testCase)
            folder = testCase.makeVirtualBucketFolder("vb", "my-bucket");
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.recordOpen(registry, folder, "my-bucket", "", ...
                datetime(2024, 1, 2, TimeZone="UTC")));
            testCase.openList();

            sendListRequest("setLabel", struct("bucket", "my-bucket", "label", "Mouse V1"))
            testCase.verifyEqual(testCase.App.ListedBuckets.Label, "Mouse V1");
            sendListRequest("setPinned", struct("path", folder, "pinned", true))
            testCase.verifyEqual(testCase.App.ListedBuckets.Pinned, true);
            sendListRequest("setLabel", struct("bucket", "my-bucket", "label", ""))
            testCase.verifyEqual(testCase.App.ListedBuckets.Label, "");
            sendListRequest("removeFolder", struct("path", folder))
            testCase.verifyEmpty(testCase.App.ListedBuckets);
            testCase.verifyTrue(isfolder(folder), "The folder itself is left as it is.");
        end

        function testPinningAFolderBelowTheRootRecordsItWithoutATime(testCase)
            rootFolder = fullfile(testCase.Folder, "root");
            scanned = testCase.makeVirtualBucketFolder(fullfile("root", "d-1"), "d-1");
            ebrains.bucket.setVirtualBucketRoot(rootFolder)
            testCase.openList();

            sendListRequest("setPinned", struct("path", scanned, "pinned", true))

            folders = ebrains.bucket.internal.registry.readRegistry().Folders;
            testCase.verifyEqual(folders.Path, scanned);
            testCase.verifyEqual(folders.Bucket, "d-1");
            testCase.verifyTrue(folders.Pinned);
            testCase.verifyTrue(isnat(folders.LastOpened));
        end

        function testChooseRootRecordsTheChosenFolder(testCase)
            rootFolder = fullfile(testCase.Folder, "root");
            scanned = testCase.makeVirtualBucketFolder(fullfile("root", "d-1"), "d-1");
            testCase.ChosenFolder = rootFolder;
            testCase.openList();
            testCase.assertEmpty(testCase.App.ListedBuckets);

            sendListRequest("chooseRoot")

            testCase.verifyEqual(ebrains.bucket.getVirtualBucketRoot(), ...
                ebrains.bucket.internal.absoluteFolderPath(rootFolder));
            testCase.verifyEqual(testCase.App.ListedBuckets.Path, scanned);
        end

        function testChooseFolderOpensTheChosenVirtualBucket(testCase)
            folder = testCase.makeVirtualBucketFolder("vb", "my-bucket");
            testCase.ChosenFolder = folder;
            testCase.openList();

            sendListRequest("chooseFolder")

            testCase.verifyEqual(testCase.App.LocalFolder, folder);
        end

        function testCancelledFolderDialogLeavesTheList(testCase)
            testCase.openList();

            sendListRequest("chooseFolder")
            sendListRequest("chooseRoot")

            testCase.verifyEqual(testCase.ChooserTitles, ["Choose the folder of a virtual bucket", ...
                "Choose the folder where new virtual buckets are made"]);
            testCase.verifyEqual(testCase.App.LocalFolder, "");
            testCase.verifyEqual(ebrains.bucket.getVirtualBucketRoot(), "");
        end

        function testChoosingAFolderThatIsNotAVirtualBucketSaysSo(testCase)
            plain = fullfile(testCase.Folder, "plain");
            mkdir(plain)
            testCase.ChosenFolder = plain;
            testCase.openList();

            sendListRequest("chooseFolder")

            testCase.verifyEqual(testCase.App.LocalFolder, "");
            testCase.verifyFalse(isfile(fullfile(plain, ".ebrains", "bucket.json")));
        end

        function testEmptyFolderArgumentIsRefused(testCase)
            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser("", Client=testCase.Client), ...
                'EBRAINS:Bucket:InvalidFolder');
        end
    end

    methods (Access = private)
        function openApp(testCase, folder, options)
        % openApp - Open the browser on a folder, with the mock client and every dialog replaced
        %
        %   The bucket is "my-bucket" unless BucketName says otherwise;
        %   an empty BucketName leaves it to the folder. The options are
        %   passed as one cell, since Name=Value syntax cannot be mixed
        %   with comma-separated name-value pairs in a call.
            arguments
                testCase
                folder string {mustBeScalarOrEmpty} = string.empty
                options.BucketName string {mustBeScalarOrEmpty} = "my-bucket"
                options.Prefix (1,1) string
                options.Downloader (1,1) function_handle = @writeAbc
                options.Opener (1,1) function_handle = @web
            end
            if isempty(options.BucketName)
                options = rmfield(options, "BucketName");
            end
            options.Client = testCase.Client;
            options.Confirmer = @(message, title, ~) refuseConfirmation(testCase, message, title);
            options.FolderChooser = @(~, title) chooseRecordedFolder(testCase, title);
            options.Alerter = @(~, message, title, varargin) recordAlert(testCase, message, title);
            options.ProgressDialog = @ebrains.mocks.FakeProgressDialog;
            options.Visible = "off";
            optionPairs = namedargs2cell(options);
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(folder, optionPairs{:});
        end

        function openList(testCase)
        % openList - Open the browser without a folder, on the list of virtual buckets
            testCase.openApp(BucketName=string.empty);
        end

        function folder = makeVirtualBucketFolder(testCase, name, bucketName)
        % makeVirtualBucketFolder - Make a folder of the test a virtual bucket that was never listed
            folder = fullfile(testCase.Folder, name);
            mkdir(folder)
            ebrains.bucket.internal.metadata.writeBucketInfo(folder, bucketName, "")
            folder = ebrains.bucket.internal.absoluteFolderPath(folder);
        end

        function target = openWithDownloadedFile(testCase)
        % openWithDownloadedFile - Open a new virtual bucket of one object and download it
        %
        %   The file a.txt holds "abc" and has the time of its object, as
        %   a download gives it, so it is downloaded. The bucket was listed
        %   since the browser opened.
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, "a.txt", 3);
            testCase.openApp(target);
            testCase.Client.addResponse('OK', struct('url', 'https://store.example.org/download?sig=1'));
            sendPageEvent("download", "a.txt")
            testCase.assertEqual(testCase.App.Files.State, "downloaded");
        end
    end
end

function assumeCaseInsensitive(testCase)
% assumeCaseInsensitive - Filter the test unless the test folder ignores the case of names
    probeFile = fullfile(testCase.Folder, "case-probe");
    writeFile(probeFile, "");
    isInsensitive = isfile(fullfile(testCase.Folder, "CASE-PROBE"));
    delete(probeFile)
    testCase.assumeTrue(isInsensitive, 'The file system of the test folder tells names apart by case.');
end

function sendPageEvent(name, paths)
% sendPageEvent - Send a request about files to the browser of the bucket, as its page does
    arguments
        name (1,1) string
        paths string = strings(1, 0)
    end
    sendRequest("Virtual bucket - my-bucket", name, struct("paths", {cellstr(paths)}))
end

function sendListRequest(name, data)
% sendListRequest - Send a request about the list of virtual buckets to the browser, as its page does
    arguments
        name (1,1) string
        data (1,1) struct = struct()
    end
    sendRequest("Virtual buckets", name, data)
end

function sendRequest(figureName, name, data)
% sendRequest - Send a request to the page of the figure of the name, with its data as JSON text
%
%   A browser left open by an earlier run has a figure of the same
%   name, so the lookup refuses more than one match rather than pick one.
    browserFigure = findall(groot, "Type", "figure", "Name", figureName);
    if numel(browserFigure) ~= 1
        error('EBRAINS:Test:AmbiguousBrowser', ...
            '%d figures are named "%s"; close the browsers of earlier runs.', numel(browserFigure), figureName)
    end
    page = findall(browserFigure, "Type", "uihtml");
    page.HTMLEventReceivedFcn(page, struct("HTMLEventName", name, "HTMLEventData", jsonencode(data)));
end

function addListing(client, names, bytes, hashes)
% addListing - Queue the responses to an update from the bucket
%
%   The browser counts the objects with the stat endpoint before it lists
%   them. The listing then gets one page, and the empty page that ends it.
%   Objects have no checksum unless hashes are given.
    if nargin < 4
        hashes = repmat("", size(names));
    end
    objects = struct( ...
        'name', cellstr(reshape(names, [], 1)), ...
        'bytes', num2cell(reshape(bytes, [], 1)), ...
        'last_modified', '2000-01-01T00:00:00', ...
        'hash', cellstr(reshape(hashes, [], 1)), ...
        'content_type', 'application/octet-stream');
    client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', numel(objects), 'bytes', 0));
    client.addResponse('OK', struct('objects', objects));
    client.addResponse('OK', struct('objects', []));
end

function giveTimeOfListedObjects(filePath)
% giveTimeOfListedObjects - Give a file the time that addListing gives every object, as a download does
    setFileTime(filePath, datetime(2000, 1, 1, TimeZone="UTC"));
end

function setFileTime(filePath, time)
% setFileTime - Set the modification time of a file
    java.io.File(char(filePath)).setLastModified(round(posixtime(time) * 1000));
end

function editThenWrite(localFile, target)
% editThenWrite - Downloader that edits the local file during the transfer, then delivers the download
    writeFile(localFile, "xyz");
    writeFile(target, "abc");
end

function folder = chooseRecordedFolder(testCase, title)
% chooseRecordedFolder - Folder chooser that records the title and answers with ChosenFolder
    testCase.ChooserTitles(end+1) = title;
    folder = testCase.ChosenFolder;
end

function recordURL(testCase, url)
% recordURL - Opener that records the address instead of showing it
    testCase.OpenedURL(end+1) = url;
end

function recordAlert(testCase, message, title)
% recordAlert - Alerter that records the alert instead of showing it
    testCase.Alerts(end+1, :) = [title, message];
end

function tf = refuseConfirmation(testCase, message, title)
% refuseConfirmation - Confirmer that records the question and answers Cancel
    testCase.Confirmations(end+1, :) = [title, message];
    tf = false;
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
