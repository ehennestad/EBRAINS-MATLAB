classdef VirtualBucketBrowserTest < matlab.unittest.TestCase
    % VirtualBucketBrowserTest - Tests of the virtual bucket browser with its page
    %
    % The browser runs with a MockBucketsClient and a stand-in for the
    % downloader, so no request reaches the Data Proxy. The requests of
    % the page are sent to the callback of its uihtml component, as the
    % page sends them. A confirmation dialog waits for a user, so the
    % browser is given a Confirmer that records the question and refuses.

    properties
        Client ebrains.mocks.MockBucketsClient
        Folder string
        App ebrains.bucket.app.VirtualBucketBrowser

        % OpenedURL - Addresses the browser asked its opener to show
        OpenedURL (1,:) string = string.empty(1, 0)

        % Confirmations - Titles and messages of the confirmations the browser asked for, one row each
        Confirmations (:,2) string = strings(0, 2)
    end

    methods (TestClassSetup)
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
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(target, BucketName="my-bucket", ...
                Prefix="set", Client=testCase.Client, Downloader=@writeAbc);
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

            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(target, ...
                Client=testCase.Client, Downloader=@writeAbc);

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
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(target, BucketName="my-bucket", ...
                Prefix="set", Client=testCase.Client, Downloader=@writeAbc);
            delete(testCase.App)

            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(target, BucketName="my-bucket", ...
                Client=testCase.Client, Downloader=@writeAbc);

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

            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(testCase.Folder, ...
                Client=testCase.Client, Downloader=@writeAbc);

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
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(target, BucketName="my-bucket", ...
                Client=testCase.Client, Downloader=@(file, varargin) editThenWrite(localFile, file), ...
                Confirmer=@(message, title, ~) refuseConfirmation(testCase, message, title));
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
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(testCase.Folder, BucketName="my-bucket", ...
                Client=testCase.Client, Downloader=@writeAbc, Opener=@(url) recordURL(testCase, url));

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
            progress = ebrains.bucket.app.internal.ListingProgress(makeDialogStub(), 20481, true);

            progress.update(4000)

            testCase.verifySubstring(char(progress.Dialog.Message), 'Listed 4,000 of about 20,481 objects.');
            testCase.verifySubstring(char(progress.Dialog.Message), 'left.');
            testCase.verifyEqual(progress.Dialog.Value, 4000 / 20481, AbsTol=1e-12);
        end

        function testProgressOfFolderShowsNoFraction(testCase)
            progress = ebrains.bucket.app.internal.ListingProgress(makeDialogStub(), 20481, false);

            progress.update(1000)

            testCase.verifyEqual(progress.Dialog.Indeterminate, "on");
            testCase.verifySubstring(char(progress.Dialog.Message), '1,000 listed so far');
        end

        function testCancelStopsTheListing(testCase)
            dialog = makeDialogStub();
            dialog.CancelRequested = true;
            progress = ebrains.bucket.app.internal.ListingProgress(dialog, 10, true);

            testCase.verifyError(@() progress.update(5), 'EBRAINS:Bucket:ListingCancelled');
        end
    end

    methods (Access = private)
        function openApp(testCase, folder)
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(folder, BucketName="my-bucket", ...
                Client=testCase.Client, Downloader=@writeAbc, ...
                Confirmer=@(message, title, ~) refuseConfirmation(testCase, message, title));
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
% sendPageEvent - Send a request to the browser as its page does
    arguments
        name (1,1) string
        paths string = strings(1, 0)
    end
    browserFigure = findall(groot, "Type", "figure", "Name", "Virtual bucket - my-bucket");
    page = findall(browserFigure, "Type", "uihtml");
    data = jsonencode(struct("paths", {cellstr(paths)}));
    page.HTMLEventReceivedFcn(page, struct("HTMLEventName", name, "HTMLEventData", data));
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

function dialog = makeDialogStub()
% makeDialogStub - Stand-in for a uiprogressdlg, with the properties ListingProgress uses
%
%   uiprogressdlg needs a visible figure. ListingProgress keeps the struct
%   in its Dialog property, where a test reads what it set.
    dialog = struct("CancelRequested", false, "Indeterminate", "on", "Value", 0, "Message", "");
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

function recordURL(testCase, url)
% recordURL - Opener that records the address instead of showing it
    testCase.OpenedURL(end+1) = url;
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
