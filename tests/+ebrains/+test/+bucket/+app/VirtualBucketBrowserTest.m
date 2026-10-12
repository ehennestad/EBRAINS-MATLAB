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
            testCase.verifyEqual(testCase.App.Files.State, ["Downloaded"; "OnlineOnly"]);
            testCase.verifyFalse(testCase.App.IsListed);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testNewFolderIsFilledFromListing(testCase)
            target = fullfile(testCase.Folder, "virtual");
            addListing(testCase.Client, ["a.txt", "sub/b.txt"], [3, 3]);

            testCase.openApp(target);

            testCase.verifyEqual(testCase.App.Files.State, ["OnlineOnly"; "OnlineOnly"]);
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
            testCase.verifyEqual(files.State, ["Differs"; "LocalOnly"; "OnlineOnly"]);
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
            testCase.verifyEqual(testCase.App.Files.State, ["OnlineOnly"; "Downloaded"]);
            testCase.Client.verifyRequestURL(3, '/buckets/my-bucket/sub/b.txt');
        end

        function testOnlineOnlyEmptiesFileThatMatchesItsObject(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            testCase.openApp(testCase.Folder);
            addListing(testCase.Client, "a.txt", 3);
            sendPageEvent("update")

            sendPageEvent("onlineOnly", "a.txt")

            testCase.verifyEqual(dir(fullfile(testCase.Folder, "a.txt")).bytes, 0);
            testCase.verifyEqual(testCase.App.Files.State, "OnlineOnly");
        end

        function testPrefixMustNameAFolder(testCase)
            testCase.verifyError(@() ebrains.bucket.app.VirtualBucketBrowser("my-bucket", ...
                testCase.Folder, Prefix="results", Client=testCase.Client), 'EBRAINS:Bucket:InvalidPrefix');
        end
    end

    methods (Access = private)
        function openApp(testCase, folder)
            testCase.App = ebrains.bucket.app.VirtualBucketBrowser("my-bucket", folder, ...
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
