classdef VirtualBucketBrowserTest < matlab.unittest.TestCase
    % VirtualBucketBrowserTest - Tests of the virtual bucket browser with its page
    %
    % The browser runs with a MockBucketsClient and a stand-in for the
    % downloader, so no request reaches the Data Proxy. The requests of
    % the page are sent to the callback of its uihtml component, as the
    % page sends them. Only actions that need no confirmation are tested,
    % since a confirmation dialog waits for a user.

    properties
        Client ebrains.mocks.MockBucketsClient
        Folder string
        App ebrains.bucket.app.VirtualBucketBrowser
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
            testCase.Client.verifyRequestURL(3, '/buckets/my-bucket/sub/b.txt');
        end

        function testOnlineOnlyEmptiesFileThatMatchesItsObject(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
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
            testCase.Client.verifyRequestURL(3, '/buckets/my-bucket/set/sub/b.txt');
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

        function testOtherBucketIsRefused(testCase)
            testCase.openApp(testCase.Folder);
            delete(testCase.App)

            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser(testCase.Folder, ...
                BucketName="other-bucket", Client=testCase.Client), 'EBRAINS:Bucket:OtherBucket');
        end
    end

    methods (Access = private)
        function openApp(testCase, folder)
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser(folder, BucketName="my-bucket", ...
                Client=testCase.Client, Downloader=@writeAbc);
        end
    end
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

function addListing(client, names, bytes)
% addListing - Queue the stat and the single page of a listing
    objects = struct( ...
        'name', cellstr(reshape(names, [], 1)), ...
        'bytes', num2cell(reshape(bytes, [], 1)), ...
        'last_modified', '2000-01-01T00:00:00', ...
        'hash', '', ...
        'content_type', 'application/octet-stream');
    client.addResponse('OK', struct('name', 'my-bucket', 'objects_count', numel(objects), 'bytes', 0));
    client.addResponse('OK', struct('objects', objects));
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
