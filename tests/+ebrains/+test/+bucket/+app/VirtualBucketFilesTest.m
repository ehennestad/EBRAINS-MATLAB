classdef VirtualBucketFilesTest < matlab.unittest.TestCase
    % VirtualBucketFilesTest - Unit tests for the file helpers of the virtual bucket browser
    %
    % The helpers judge the state of the files of a virtual bucket, and
    % create and empty placeholder files. They need no user interface and
    % send no request.

    properties
        Folder string
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = string(folderFixture.Folder);
        end
    end

    methods (Test)
        %% classifyFiles
        function testLocalFilesAloneAreJudgedBySize(testCase)
            localFiles = makeFiles(["b.txt", "a.txt"], [0, 5]);

            files = ebrains.bucket.app.internal.classifyFiles(localFiles);

            testCase.verifyEqual(files.Path, ["a.txt"; "b.txt"]);
            testCase.verifyEqual(files.State, ["downloaded"; "online_only"]);
            testCase.verifyEqual(files.RemoteBytes, [NaN; NaN]);
        end

        function testListingGivesEveryState(testCase)
            uploaded = datetime(2026, 1, 1, TimeZone="UTC");
            before = uploaded - days(1);
            after = uploaded + days(1);
            localFiles = makeFiles( ...
                ["placeholder", "downloaded", "resized", "outdated", "extra"], ...
                [0, 3, 4, 3, 7], [after, after, after, before, after]);
            remoteFiles = makeFiles( ...
                ["placeholder", "downloaded", "resized", "outdated", "new"], ...
                [3, 3, 3, 3, 3], repmat(uploaded, 1, 5));

            files = ebrains.bucket.app.internal.classifyFiles(localFiles, remoteFiles);

            expected = dictionary( ...
                ["placeholder", "downloaded", "resized", "outdated", "extra", "new"], ...
                ["online_only", "downloaded", "differs", "differs", "local_only", "online_only"]);
            testCase.verifyEqual(files.State, expected(files.Path));
            testCase.verifyEqual(files.LocalBytes(files.Path == "new"), NaN);
            testCase.verifyEqual(files.RemoteBytes(files.Path == "extra"), NaN);
        end

        function testIgnoringCaseMatchesLocalFileToItsObject(testCase)
            uploaded = datetime(2024, 1, 1, TimeZone="UTC");
            localFiles = makeFiles("data.txt", 3, uploaded + days(1));
            remoteFiles = makeFiles("Data.txt", 3, uploaded);

            files = ebrains.bucket.app.internal.classifyFiles(localFiles, remoteFiles, IgnoreCase=true);

            testCase.verifyEqual(files.Path, "Data.txt");
            testCase.verifyEqual(files.State, "downloaded");
            testCase.verifyEqual(files.LocalBytes, 3);
        end

        function testEmptyObjectWithEmptyFileIsDownloaded(testCase)
            files = ebrains.bucket.app.internal.classifyFiles( ...
                makeFiles("empty.txt", 0), makeFiles("empty.txt", 0));

            testCase.verifyEqual(files.State, "downloaded");
        end

        function testEmptyListingMarksEveryFileLocalOnly(testCase)
            files = ebrains.bucket.app.internal.classifyFiles( ...
                makeFiles("a.txt", 3), makeFiles(strings(0, 1), zeros(0, 1)));

            testCase.verifyEqual(files.State, "local_only");
        end

        %% Placeholders
        function testCreatePlaceholderFilesKeepsExistingFiles(testCase)
            writeFile(fullfile(testCase.Folder, "sub", "kept.txt"), "abc");

            ebrains.bucket.app.internal.createPlaceholderFiles(testCase.Folder, ["sub/kept.txt", "sub/deep/new.txt"]);

            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "sub", "kept.txt")), 'abc');
            testCase.verifyTrue(isfile(fullfile(testCase.Folder, "sub", "deep", "new.txt")));
            testCase.verifyEqual(dir(fullfile(testCase.Folder, "sub", "deep", "new.txt")).bytes, 0);
        end

        function testReplaceWithPlaceholdersEmptiesFiles(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");

            ebrains.bucket.app.internal.replaceWithPlaceholders(testCase.Folder, "a.txt");

            testCase.verifyEqual(dir(fullfile(testCase.Folder, "a.txt")).bytes, 0);
        end

        function testReplaceWithPlaceholdersChecksEveryPathFirst(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");

            testCase.verifyError(@() ebrains.bucket.app.internal.replaceWithPlaceholders( ...
                testCase.Folder, ["a.txt", "missing.txt"]), 'EBRAINS:Bucket:FileNotFound');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a.txt")), 'abc');
        end
    end
end

function files = makeFiles(paths, bytes, modifiedTimes)
% makeFiles - File table with unknown times unless given
    arguments
        paths string
        bytes double
        modifiedTimes datetime = NaT(numel(paths), 1)
    end
    files = ebrains.bucket.sync.internal.makeFileTable(paths, bytes, modifiedTimes);
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
