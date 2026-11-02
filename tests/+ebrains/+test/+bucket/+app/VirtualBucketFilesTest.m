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
            % A download has the time of its object, so "edited" was
            % changed after it was downloaded
            localFiles = makeFiles( ...
                ["placeholder", "downloaded", "edited", "resized", "outdated", "extra"], ...
                [0, 3, 3, 4, 3, 7], [after, uploaded, after, after, before, after]);
            remoteFiles = makeFiles( ...
                ["placeholder", "downloaded", "edited", "resized", "outdated", "new"], ...
                [3, 3, 3, 3, 3, 3], repmat(uploaded, 1, 6));

            files = ebrains.bucket.app.internal.classifyFiles(localFiles, remoteFiles);

            expected = dictionary( ...
                ["placeholder", "downloaded", "edited", "resized", "outdated", "extra", "new"], ...
                ["online_only", "downloaded", "differs", "differs", "differs", "local_only", "online_only"]);
            testCase.verifyEqual(files.State, expected(files.Path));
            testCase.verifyEqual(files.LocalBytes(files.Path == "new"), NaN);
            testCase.verifyEqual(files.RemoteBytes(files.Path == "extra"), NaN);
            testCase.verifyEqual(files.RemoteTime(files.Path == "new"), uploaded);
        end

        function testUnknownTimeOfObjectLeavesFileDownloaded(testCase)
            % A sync to the bucket records an uploaded file with no time
            localFiles = makeFiles("uploaded.txt", 3, datetime(2026, 1, 2, TimeZone="UTC"));
            remoteFiles = makeFiles("uploaded.txt", 3, NaT(TimeZone="UTC"));

            files = ebrains.bucket.app.internal.classifyFiles(localFiles, remoteFiles);

            testCase.verifyEqual(files.State, "downloaded");
            testCase.verifyTrue(isnat(files.RemoteTime));
        end

        function testIgnoringCaseMatchesLocalFileToItsObject(testCase)
            uploaded = datetime(2024, 1, 1, TimeZone="UTC");
            localFiles = makeFiles("data.txt", 3, uploaded);
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

        function testCreatePlaceholderFilesLeavesWhatIsInTheWay(testCase)
            % A local file "a" sits where the folder of "a/b.txt" must go,
            % and a folder where the placeholder "dir.dat" must go
            writeFile(fullfile(testCase.Folder, "a"), "local");
            writeFile(fullfile(testCase.Folder, "kept.dat"), "kept");
            mkdir(fullfile(testCase.Folder, "dir.dat"))

            pathsWithoutPlaceholder = ebrains.bucket.app.internal.createPlaceholderFiles( ...
                testCase.Folder, ["a/b.txt", "kept.dat", "dir.dat", "new/c.txt"]);

            testCase.verifyEqual(pathsWithoutPlaceholder, ["a/b.txt"; "dir.dat"]);
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a")), 'local');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "kept.dat")), 'kept');
            testCase.verifyEqual(dir(fullfile(testCase.Folder, "new", "c.txt")).bytes, 0);
        end

        function testCreatePlaceholderFilesDoesNotFollowADanglingLink(testCase)
            outsideFolder = string(testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            target = fullfile(outsideFolder, "missing.dat");
            makeLink(testCase, target, fullfile(testCase.Folder, "x.dat"));

            pathsWithoutPlaceholder = ebrains.bucket.app.internal.createPlaceholderFiles(testCase.Folder, "x.dat");

            testCase.verifyEqual(pathsWithoutPlaceholder, "x.dat");
            testCase.verifyFalse(isfile(target));
        end

        function testReplaceWithPlaceholdersEmptiesFiles(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            files = ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "a.txt");

            ebrains.bucket.app.internal.replaceWithPlaceholders(testCase.Folder, files);

            testCase.verifyEqual(dir(fullfile(testCase.Folder, "a.txt")).bytes, 0);
        end

        function testReplaceWithPlaceholdersChecksEveryPathFirst(testCase)
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            files = [ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "a.txt"); ...
                makeFiles("missing.txt", 3)];

            testCase.verifyError(@() ebrains.bucket.app.internal.replaceWithPlaceholders( ...
                testCase.Folder, files), 'EBRAINS:Bucket:FileNotFound');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a.txt")), 'abc');
        end

        function testReplaceWithPlaceholdersRefusesAChangedFile(testCase)
            % The file keeps its size, so only its time tells that it changed
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            writeFile(fullfile(testCase.Folder, "b.txt"), "xyz");
            files = [ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "a.txt"); ...
                ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "b.txt")];
            laterTime = datetime(2030, 1, 1, TimeZone="UTC");
            java.io.File(char(fullfile(testCase.Folder, "b.txt"))).setLastModified(round(posixtime(laterTime) * 1000));

            testCase.verifyError(@() ebrains.bucket.app.internal.replaceWithPlaceholders( ...
                testCase.Folder, files), 'EBRAINS:Bucket:LocalFileChanged');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a.txt")), 'abc');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "b.txt")), 'xyz');
        end

        function testReplaceWithPlaceholdersRefusesASymbolicLink(testCase)
            % Opening the link for writing would empty the file it points to
            outsideFolder = string(testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            target = fullfile(outsideFolder, "precious.txt");
            writeFile(target, "precious");
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            makeLink(testCase, target, fullfile(testCase.Folder, "link.dat"));
            files = [ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "a.txt"); ...
                ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "link.dat")];

            testCase.verifyError(@() ebrains.bucket.app.internal.replaceWithPlaceholders( ...
                testCase.Folder, files), 'EBRAINS:Bucket:FileIsLink');
            testCase.verifyEqual(fileread(target), 'precious');
            testCase.verifyEqual(fileread(fullfile(testCase.Folder, "a.txt")), 'abc');
        end

        function testReplaceWithPlaceholdersAcceptsAFileWithoutATime(testCase)
            % A file whose time cannot be read has an unknown time at the
            % decision and at the check alike, so it is not a changed file.
            writeFile(fullfile(testCase.Folder, "a.txt"), "abc");
            java.io.File(char(fullfile(testCase.Folder, "a.txt"))).setLastModified(0);
            files = ebrains.bucket.sync.internal.listLocalFile(testCase.Folder, "a.txt");
            testCase.assumeTrue(isnat(files.ModifiedTime), 'The file system keeps a time of zero apart from none.');

            ebrains.bucket.app.internal.replaceWithPlaceholders(testCase.Folder, files);

            testCase.verifyEqual(dir(fullfile(testCase.Folder, "a.txt")).bytes, 0);
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

function makeLink(testCase, target, linkPath)
% makeLink - Create a symbolic link, which the helpers find through MATLAB or Java
    testCase.assumeFalse(ispc, 'Symbolic links are created with ln, which Windows does not have.');
    testCase.assumeTrue(~isMATLABReleaseOlderThan("R2024b") || usejava('jvm'), ...
        'Before R2024b, symbolic links are found through Java.');
    [status, output] = system("ln -s '" + target + "' '" + linkPath + "'");
    testCase.assertEqual(status, 0, output);
end
