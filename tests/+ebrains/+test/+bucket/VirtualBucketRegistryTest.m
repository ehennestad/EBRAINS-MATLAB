classdef VirtualBucketRegistryTest < matlab.unittest.TestCase
    % VirtualBucketRegistryTest - Tests of the registry of virtual buckets and the configuration folder
    %
    % The registry is virtual-buckets.json in the configuration folder,
    % laid out as spec/README.md#virtual-bucket-registry of the
    % ebrains-bucket-sync package describes; the fixtures of that contract
    % run in SpecConformanceTest. Each test points the configuration
    % folder at a folder of its own through EBRAINS_BUCKET_SYNC_CONFIG_DIR,
    % so no test touches the registry of the user.

    properties
        Folder string
        ConfigFolder string
    end

    methods (TestMethodSetup)
        function setUp(testCase)
            folderFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = string(folderFixture.Folder);
            testCase.ConfigFolder = fullfile(testCase.Folder, "config");
            testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture( ...
                "EBRAINS_BUCKET_SYNC_CONFIG_DIR", testCase.ConfigFolder));
        end
    end

    methods (Test)
        %% Configuration folder
        function testConfigFolderFollowsThePlatformRule(testCase)
            testCase.unsetEnvironment(["EBRAINS_BUCKET_SYNC_CONFIG_DIR", "XDG_CONFIG_HOME", "LOCALAPPDATA"])
            home = fullfile(testCase.Folder, "home");

            testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform="mac", Home=home), ...
                fullfile(home, "Library", "Application Support", "ebrains-bucket-sync"));
            testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform="windows", Home=home), ...
                fullfile(home, "AppData", "Local", "ebrains-bucket-sync"));
            testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform="unix", Home=home), ...
                fullfile(home, ".config", "ebrains-bucket-sync"));
        end

        function testConfigFolderUsesTheFoldersOfTheEnvironment(testCase)
            testCase.unsetEnvironment("EBRAINS_BUCKET_SYNC_CONFIG_DIR")
            testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture("XDG_CONFIG_HOME", "/xdg"));
            testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture("LOCALAPPDATA", "C:\local"));
            home = fullfile(testCase.Folder, "home");

            testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform="unix", Home=home), ...
                fullfile("/xdg", "ebrains-bucket-sync"));
            testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform="windows", Home=home), ...
                fullfile("C:\local", "ebrains-bucket-sync"));
            testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform="mac", Home=home), ...
                fullfile(home, "Library", "Application Support", "ebrains-bucket-sync"), ...
                "The environment folders of the other platforms do not apply on macOS.");
        end

        function testTheEnvironmentVariableNamesTheConfigFolderOnEveryPlatform(testCase)
            for platform = ["mac", "windows", "unix"]
                testCase.verifyEqual(ebrains.bucket.internal.configFolder(Platform=platform), testCase.ConfigFolder);
            end
            testCase.verifyEqual(ebrains.bucket.internal.registry.registryPath(), ...
                fullfile(testCase.ConfigFolder, "virtual-buckets.json"));
        end

        %% Reading and writing
        function testMissingFileIsAnEmptyRegistry(testCase)
            registry = ebrains.bucket.internal.registry.readRegistry();

            testCase.verifyEqual(registry, ebrains.bucket.internal.registry.emptyRegistry());
            testCase.verifyEqual(registry.Root, "");
            testCase.verifyEmpty(registry.Labels);
            testCase.verifyEmpty(registry.Folders);
        end

        function testWrittenRegistryReadsBackAndCreatesTheFolder(testCase)
            registry = fullRegistry();

            ebrains.bucket.internal.registry.writeRegistry(registry)

            testCase.verifyTrue(isfile(fullfile(testCase.ConfigFolder, "virtual-buckets.json")));
            % The file holds the labels and the folders sorted by name
            written = ebrains.bucket.internal.registry.readRegistry();
            testCase.verifyEqual(written.Root, registry.Root);
            testCase.verifyEqual(written.Labels, sortrows(registry.Labels, "Bucket"));
            testCase.verifyEqual(written.Folders, sortrows(registry.Folders, "Path"));
        end

        function testWrittenFileIsSortedWithoutFieldsTheToolboxDoesNotKnow(testCase)
            filePath = ebrains.bucket.internal.registry.registryPath();
            ebrains.bucket.internal.metadata.writeTextFile(filePath, ...
                "{""format_version"": 1, ""root"": null, ""theme"": ""dark"", " + ...
                """buckets"": [{""bucket"": ""z"", ""label"": ""Z""}, {""bucket"": ""a"", ""label"": ""A"", ""color"": ""red""}], " + ...
                """folders"": [{""path"": ""/z"", ""bucket"": ""z"", ""prefix"": """", ""pinned"": false, ""last_opened"": null}, " + ...
                "{""path"": ""/a"", ""bucket"": ""a"", ""prefix"": ""sub/"", ""pinned"": true, " + ...
                """last_opened"": ""2024-01-02T03:04:05Z"", ""note"": ""x""}]}");

            ebrains.bucket.internal.registry.writeRegistry(ebrains.bucket.internal.registry.readRegistry())

            data = jsondecode(fileread(filePath));
            testCase.verifyFalse(isfield(data, "theme"));
            testCase.verifyEqual({data.buckets.bucket}, {'a', 'z'});
            testCase.verifyEqual(fieldnames(data.buckets), {'bucket'; 'label'});
            testCase.verifyEqual({data.folders.path}, {'/a', '/z'});
            testCase.verifyEqual(data.folders(1).last_opened, '2024-01-02T03:04:05Z');
            testCase.verifyEqual(data.folders(2).last_opened, []);
            testCase.verifyEqual(data.root, []);
        end

        function testInvalidRegistryIsRefusedByName(testCase)
            filePath = ebrains.bucket.internal.registry.registryPath();
            ebrains.bucket.internal.metadata.writeTextFile(filePath, '{"format_version": 1, "root": null, "buckets": []}');

            exception = MException.empty;
            try
                ebrains.bucket.internal.registry.readRegistry();
            catch exception
            end

            testCase.assertNotEmpty(exception, "The file is refused.");
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidRegistry');
            testCase.verifySubstring(exception.message, filePath);
            testCase.verifySubstring(exception.message, "it has no folders");
            testCase.verifySubstring(exception.message, "corrected or deleted");
        end

        function testNewerFormatVersionIsRefused(testCase)
            ebrains.bucket.internal.metadata.writeTextFile(ebrains.bucket.internal.registry.registryPath(), ...
                '{"format_version": 2, "root": null, "buckets": [], "folders": []}');

            testCase.verifyError(@() ebrains.bucket.internal.registry.readRegistry(), ...
                'EBRAINS:Bucket:UnknownRegistryFormat');
        end

        function testUpdateReadsChangesAndWrites(testCase)
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.setLabel(registry, "d-1", "Mouse V1"));
            registry = ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.setLabel(registry, "d-2", "Rat S1"));

            testCase.verifyEqual(registry.Labels.Bucket, ["d-1"; "d-2"]);
            testCase.verifyEqual(ebrains.bucket.internal.registry.readRegistry().Labels.Label, ["Mouse V1"; "Rat S1"]);
        end

        %% Changes
        function testRecordOpenKeepsThePinAndReplacesTheTime(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();
            registry = ebrains.bucket.internal.registry.setPinned(registry, "/a", true, Bucket="old", Prefix="old/");

            registry = ebrains.bucket.internal.registry.recordOpen(registry, "/a", "new", "", openedAt());
            registry = ebrains.bucket.internal.registry.recordOpen(registry, "/b", "b", "sub/", later());
            registry = ebrains.bucket.internal.registry.recordOpen(registry, "/b", "b", "sub/", openedAt());

            testCase.verifyEqual(registry.Folders, ebrains.bucket.internal.registry.makeFolderTable( ...
                ["/a"; "/b"], ["new"; "b"], [""; "sub/"], [true; false], [openedAt(); openedAt()]));
        end

        function testOpeningRecordsTheTimeInUtcToTheSecond(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();
            oslo = datetime(2024, 1, 2, 4, 4, 5.678, TimeZone="+01:00");

            registry = ebrains.bucket.internal.registry.recordOpen(registry, "/a", "a", "", oslo);

            testCase.verifyEqual(registry.Folders.LastOpened, openedAt());
            written = ebrains.bucket.internal.registry.formatRegistry(registry);
            testCase.verifyEqual(ebrains.bucket.internal.registry.parseRegistry(written), registry);
        end

        function testABucketOrPrefixTheFileCannotHoldIsRefusedBeforeItIsRecorded(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();
            cases = {"", ""; "a", "results"; "a", "../x/"};

            for i = 1:size(cases, 1)
                testCase.verifyError(@() ebrains.bucket.internal.registry.recordOpen( ...
                    registry, "/a", cases{i, 1}, cases{i, 2}, openedAt()), 'EBRAINS:Bucket:InvalidRegistryEntry');
                testCase.verifyError(@() ebrains.bucket.internal.registry.setPinned( ...
                    registry, "/a", true, Bucket=cases{i, 1}, Prefix=cases{i, 2}), ...
                    'EBRAINS:Bucket:InvalidRegistryEntry');
            end
        end

        function testUnpinningAnUnrecordedFolderChangesNothing(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();

            registry = ebrains.bucket.internal.registry.setPinned(registry, "/a", false);
            registry = ebrains.bucket.internal.registry.setPinned(registry, "/b", false, Bucket="b", Prefix="");

            testCase.verifyEmpty(registry.Folders);
        end

        function testRootWithoutSubfoldersGivesNoChildren(testCase)
            writeFile(fullfile(testCase.Folder, "file.txt"), "")

            paths = ebrains.bucket.internal.registry.rootChildren(testCase.Folder);

            testCase.verifyEqual(paths, strings(0, 1));
        end

        function testConfigFolderOfThisPlatformIsAbsoluteAndNamedAfterThePackage(testCase)
            testCase.unsetEnvironment("EBRAINS_BUCKET_SYNC_CONFIG_DIR")

            folder = ebrains.bucket.internal.configFolder();

            [~, name] = fileparts(folder);
            testCase.verifyEqual(name, "ebrains-bucket-sync");
            testCase.verifyTrue(startsWith(folder, "/") || ~isempty(regexp(folder, '^[A-Za-z]:', 'once')));
        end

        function testRootChildrenAreWrittenAsRecordedPaths(testCase)
            mkdir(fullfile(testCase.Folder, "a"))

            paths = ebrains.bucket.internal.registry.rootChildren(testCase.Folder + filesep + "." + filesep);

            testCase.verifyEqual(paths, fullfile(ebrains.bucket.internal.absoluteFolderPath(testCase.Folder), "a"));
        end

        function testPinningAnUnrecordedFolderNeedsItsBucketAndRecordsItWithoutATime(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();

            testCase.verifyError(@() ebrains.bucket.internal.registry.setPinned(registry, "/a", true), ...
                'EBRAINS:Bucket:NotRecorded');
            registry = ebrains.bucket.internal.registry.setPinned(registry, "/a", true, Bucket="a", Prefix="");
            registry = ebrains.bucket.internal.registry.setPinned(registry, "/a", false);

            testCase.verifyEqual(registry.Folders, ebrains.bucket.internal.registry.makeFolderTable( ...
                "/a", "a", "", false, NaT(TimeZone="UTC")));
        end

        function testEmptyLabelRemovesTheLabel(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();
            registry = ebrains.bucket.internal.registry.setLabel(registry, "d-1", "Mouse V1");
            registry = ebrains.bucket.internal.registry.setLabel(registry, "d-2", "  kept as given ");

            registry = ebrains.bucket.internal.registry.setLabel(registry, "d-1", "");
            registry = ebrains.bucket.internal.registry.setLabel(registry, "never", "");

            testCase.verifyEqual(registry.Labels.Bucket, "d-2");
            testCase.verifyEqual(registry.Labels.Label, "  kept as given ");
        end

        function testRemoveFolderForgetsTheEntry(testCase)
            registry = ebrains.bucket.internal.registry.emptyRegistry();
            registry = ebrains.bucket.internal.registry.recordOpen(registry, "/a", "a", "", openedAt());

            registry = ebrains.bucket.internal.registry.removeFolder(registry, "/a");
            registry = ebrains.bucket.internal.registry.removeFolder(registry, "/never");

            testCase.verifyEmpty(registry.Folders);
        end

        %% Lists
        function testRootChildrenAreTheFoldersDirectlyBelowTheRoot(testCase)
            mkdir(fullfile(testCase.Folder, "b"))
            mkdir(fullfile(testCase.Folder, "a", "nested"))
            writeFile(fullfile(testCase.Folder, "file.txt"), "")

            testCase.verifyEqual(ebrains.bucket.internal.registry.rootChildren(testCase.Folder), ...
                [fullfile(testCase.Folder, "a"); fullfile(testCase.Folder, "b")]);
            testCase.verifyEmpty(ebrains.bucket.internal.registry.rootChildren(""));
            testCase.verifyEmpty(ebrains.bucket.internal.registry.rootChildren(fullfile(testCase.Folder, "missing")));
        end

        function testBucketInfoOfReadsTheBucketJsonOfAFolder(testCase)
            virtualBucket = makeVirtualBucketFolder(fullfile(testCase.Folder, "vb"), "d-1", "sub/");
            plain = fullfile(testCase.Folder, "plain");
            mkdir(plain)
            broken = fullfile(testCase.Folder, "broken");
            writeFile(fullfile(broken, ".ebrains", "bucket.json"), "{")

            info = ebrains.bucket.internal.registry.bucketInfoOf(virtualBucket);

            testCase.verifyEqual(info.BucketName, "d-1");
            testCase.verifyEqual(info.Prefix, "sub/");
            testCase.verifyEmpty(ebrains.bucket.internal.registry.bucketInfoOf(plain));
            testCase.verifyEmpty(ebrains.bucket.internal.registry.bucketInfoOf(broken));
            testCase.verifyEmpty(ebrains.bucket.internal.registry.bucketInfoOf(fullfile(testCase.Folder, "missing")));
        end

        function testListMergesTheRootScanWithTheRecordedFolders(testCase)
            rootFolder = fullfile(testCase.Folder, "root");
            scanned = makeVirtualBucketFolder(fullfile(rootFolder, "d-1"), "d-1", "");
            mkdir(fullfile(rootFolder, "notes"))
            elsewhere = makeVirtualBucketFolder(fullfile(testCase.Folder, "elsewhere"), "other", "");
            gone = fullfile(testCase.Folder, "gone");
            ebrains.bucket.setVirtualBucketRoot(rootFolder)
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.setLabel(registry, "d-1", "Mouse V1"));
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.recordOpen(registry, elsewhere, "other", "", openedAt()));
            ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
                ebrains.bucket.internal.registry.recordOpen(registry, gone, "gone", "x/", later()));

            rows = ebrains.bucket.listVirtualBuckets();

            testCase.verifyEqual(rows.Path, [gone; elsewhere; scanned]);
            testCase.verifyEqual(rows.Bucket, ["gone"; "other"; "d-1"]);
            testCase.verifyEqual(rows.Prefix, ["x/"; ""; ""]);
            testCase.verifyEqual(rows.Label, [""; ""; "Mouse V1"]);
            testCase.verifyEqual(rows.Pinned, [false; false; false]);
            testCase.verifyEqual(rows.LastOpened, [later(); openedAt(); NaT(TimeZone="UTC")]);
            testCase.verifyEqual(rows.Exists, [false; true; true]);
        end

        function testRootIsRecordedAsAnAbsolutePathAndEmptyRemovesIt(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(testCase.Folder));
            mkdir(fullfile(testCase.Folder, "buckets"))

            ebrains.bucket.setVirtualBucketRoot("buckets")

            testCase.verifyEqual(ebrains.bucket.getVirtualBucketRoot(), ...
                ebrains.bucket.internal.absoluteFolderPath(fullfile(testCase.Folder, "buckets")));
            ebrains.bucket.setVirtualBucketRoot("")
            testCase.verifyEqual(ebrains.bucket.getVirtualBucketRoot(), "");
        end

        function testRootMustBeAFolder(testCase)
            testCase.verifyError(@() ebrains.bucket.setVirtualBucketRoot(fullfile(testCase.Folder, "missing")), ...
                'EBRAINS:Bucket:FolderNotFound');
        end

        function testRecordFolderOpenedWarnsAndGoesOnWhenTheRegistryCannotBeRead(testCase)
            ebrains.bucket.internal.metadata.writeTextFile(ebrains.bucket.internal.registry.registryPath(), "{")
            folder = makeVirtualBucketFolder(fullfile(testCase.Folder, "vb"), "d-1", "");

            testCase.verifyWarning(@() ebrains.bucket.internal.registry.recordFolderOpened(folder, "d-1", ""), ...
                'EBRAINS:Bucket:RegistryNotUpdated');
        end

        function testRecordFolderOpenedRecordsTheAbsolutePathNow(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(testCase.Folder));
            folder = makeVirtualBucketFolder(fullfile(testCase.Folder, "vb"), "d-1", "sub/");
            before = datetime("now", TimeZone="UTC");

            ebrains.bucket.internal.registry.recordFolderOpened("vb", "d-1", "sub/")

            folders = ebrains.bucket.internal.registry.readRegistry().Folders;
            testCase.verifyEqual(folders.Path, ebrains.bucket.internal.absoluteFolderPath(folder));
            testCase.verifyEqual(folders.Bucket, "d-1");
            testCase.verifyEqual(folders.Prefix, "sub/");
            testCase.verifyFalse(folders.Pinned);
            testCase.verifyGreaterThanOrEqual(folders.LastOpened, before - seconds(1));
        end
    end

    methods (Access = private)
        function unsetEnvironment(testCase, names)
        % unsetEnvironment - Make the variables unset for the test, as an empty value counts as unset
            for name = names
                testCase.applyFixture(matlab.unittest.fixtures.EnvironmentVariableFixture(name, ""));
            end
        end
    end
end

function registry = fullRegistry()
    registry = ebrains.bucket.internal.registry.emptyRegistry();
    registry.Root = "/home/ada/EBRAINS buckets";
    registry = ebrains.bucket.internal.registry.setLabel(registry, "d-1", "Mouse V1");
    registry = ebrains.bucket.internal.registry.recordOpen(registry, "/home/ada/EBRAINS buckets/d-1", "d-1", "", openedAt());
    registry = ebrains.bucket.internal.registry.setPinned(registry, "/data/results", true, ...
        Bucket="my-collab", Prefix="results/");
end

function time = openedAt()
    time = datetime(2024, 1, 2, 3, 4, 5, TimeZone="UTC");
end

function time = later()
    time = datetime(2024, 5, 6, 7, 8, 9, TimeZone="UTC");
end

function folder = makeVirtualBucketFolder(folder, bucketName, prefix)
% makeVirtualBucketFolder - Make a folder a virtual bucket that was never listed
    folder = string(folder);
    mkdir(folder)
    ebrains.bucket.internal.metadata.writeBucketInfo(folder, bucketName, prefix)
end

function writeFile(filePath, text)
    folder = fileparts(filePath);
    if ~isfolder(folder)
        mkdir(folder)
    end
    fileID = fopen(filePath, "w");
    fwrite(fileID, text);
    fclose(fileID);
end
