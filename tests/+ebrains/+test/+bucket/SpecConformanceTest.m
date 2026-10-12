classdef SpecConformanceTest < matlab.unittest.TestCase
    % SpecConformanceTest - Run the fixtures of the sync contract shared with ebrains-bucket-sync
    %
    % The ebrains.bucket.sync functions and the Python package
    % ebrains-bucket-sync follow one contract, spec/README.md of that
    % package, and both must pass the fixtures in its spec/fixtures folder.
    % tests/fixtures/sync-spec is the copy of that folder that
    % tools/tasks/updateSyncSpecFixtures makes, at the commit its
    % vendorinfo.json records. There is one test per kind of fixture, run
    % once per fixture file, as tests/test_conformance.py of the package
    % runs them.
    %
    % A file entry of a fixture has path, bytes, modified_time (ISO 8601 in
    % UTC, or null where unknown) and hash, which may be left out, and
    % becomes a row of a file table (see
    % ebrains.bucket.sync.internal.makeFileTable). A plan row has path,
    % action, reason and bytes, as ebrains.bucket.sync.internal.planSync
    % returns them.

    properties (TestParameter)
        PlanFixture = fixtureFiles("plan")
        ExcludeFixture = fixtureFiles("exclude")
        ManifestFixture = fixtureFiles("manifest")
        FileStateFixture = fixtureFiles("file-state")
        PlaceholderFixture = fixtureFiles("placeholder")
        ManifestUpdateFixture = fixtureFiles("manifest-update")
    end

    methods (Test)
        function testPlanFixture(testCase, PlanFixture)
            fixture = readFixture(PlanFixture);

            plan = ebrains.bucket.sync.internal.planSync( ...
                toFileTable(fixture.source), toFileTable(fixture.target), ...
                Comparison=fixture.policy.comparison, Delete=fixture.policy.delete);

            testCase.verifyEqual(plan, toPlanTable(fixture.expected), fixture.description);
        end

        function testExcludeFixture(testCase, ExcludeFixture)
            fixture = readFixture(ExcludeFixture);
            paths = toStringColumn(fixture.paths);
            files = ebrains.bucket.sync.internal.makeFileTable(paths, ones(size(paths)));

            kept = ebrains.bucket.sync.internal.excludeFiles(files, toStringColumn(fixture.patterns));

            testCase.verifyEqual(kept.Path, toStringColumn(fixture.expected_kept), fixture.description);
        end

        function testManifestFixture(testCase, ManifestFixture)
            fixture = readFixture(ManifestFixture);
            text = string(fixture.text);
            entries = toFileTable(fixture.entries);

            testCase.verifyEqual(ebrains.bucket.internal.metadata.parseManifest(text), entries, ...
                "Reading the text gives the entries. " + fixture.description);
            testCase.verifyEqual(ebrains.bucket.internal.metadata.formatManifest(entries), text, ...
                "Writing the entries gives the text. " + fixture.description);
        end

        function testFileStateFixture(testCase, FileStateFixture)
            [fixture, text] = readFixture(FileStateFixture);
            localFiles = toFileTable(fixture.local);

            if isNull(text, "manifest")
                files = ebrains.bucket.app.internal.classifyFiles(localFiles, IgnoreCase=false);
            else
                files = ebrains.bucket.app.internal.classifyFiles(localFiles, ...
                    toFileTable(fixture.manifest), IgnoreCase=false);
            end

            expected = toCell(fixture.expected);
            expectedStates = table(fieldColumn(expected, "path", ""), fieldColumn(expected, "state", ""), ...
                'VariableNames', ["Path", "State"]);
            testCase.verifyEqual(files(:, ["Path", "State"]), expectedStates, fixture.description);
        end

        function testPlaceholderFixture(testCase, PlaceholderFixture)
            fixture = readFixture(PlaceholderFixture);

            % A virtual bucket that was never listed (manifest null) has an
            % empty manifest, as ebrains.bucket.internal.metadata.readManifest
            % returns it, so null and an empty list are one case here.
            plan = ebrains.bucket.sync.internal.protectPlaceholders( ...
                toPlanTable(fixture.plan), toFileTable(fixture.local), ...
                toFileTable(fixture.listing), toFileTable(fixture.manifest));

            testCase.verifyEqual(plan, toPlanTable(fixture.expected), fixture.description);
        end

        function testManifestUpdateFixture(testCase, ManifestUpdateFixture)
            fixture = readFixture(ManifestUpdateFixture);

            manifest = ebrains.bucket.sync.internal.manifestAfterPush( ...
                toFileTable(fixture.listing), toFileTable(fixture.uploaded), ...
                toStringColumn(fixture.deleted));

            testCase.verifyEqual(manifest, toFileTable(fixture.expected), fixture.description);
        end
    end
end

function files = fixtureFiles(kind)
% fixtureFiles - The fixture files of one kind, as a test parameter with one value per file
%
%   The parameter names are the file names made valid identifiers, so that
%   a test result names the fixture it ran. A kind without fixture files
%   is an error, as in the Python package: the test must not pass by
%   running nothing.
    testsFolder = fileparts(fileparts(fileparts(fileparts(mfilename("fullpath")))));
    folder = fullfile(testsFolder, "fixtures", "sync-spec", kind);
    listing = dir(fullfile(folder, "*.json"));
    if isempty(listing)
        error('EBRAINS:Test:NoFixtures', 'No fixtures in "%s".', folder)
    end
    names = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(erase({listing.name}, ".json")));
    files = cell2struct(fullfile({listing.folder}, {listing.name}), names, 2);
end

function [fixture, text] = readFixture(filePath)
% readFixture - Decode a fixture file, and return its text for what the decoding loses
    text = fileread(filePath, Encoding="UTF-8");
    fixture = jsondecode(text);
end

function tf = isNull(text, key)
% isNull - Whether a key of the fixture text is null
%
%   jsondecode reads null and an empty list both as [], and the two mean
%   different things for a manifest: null is a virtual bucket that was
%   never listed, an empty list one whose bucket held nothing.
    tf = ~isempty(regexp(text, '"' + key + '"\s*:\s*null', 'once'));
end

function items = toCell(items)
% toCell - The objects of a decoded JSON list as a cell array of scalar structs
%
%   jsondecode gives a struct array for objects that all have the same
%   fields, a cell array otherwise, and [] for an empty list.
    if isstruct(items)
        items = num2cell(items);
    elseif isempty(items)
        items = {};
    end
end

function values = fieldColumn(items, fieldName, default)
% fieldColumn - Column with one field of each object, or the default where it is missing or null
    values = repmat(default, numel(items), 1);
    for i = 1:numel(items)
        if isfield(items{i}, fieldName) && ~isempty(items{i}.(fieldName))
            values(i) = items{i}.(fieldName);
        end
    end
end

function values = toStringColumn(values)
% toStringColumn - A decoded JSON list of strings as a string column
    values = reshape(string(values), [], 1);
end

function files = toFileTable(items)
% toFileTable - File table of the file entries of a fixture
    items = toCell(items);
    files = ebrains.bucket.sync.internal.makeFileTable( ...
        fieldColumn(items, "path", ""), fieldColumn(items, "bytes", 0), ...
        parseTimes(fieldColumn(items, "modified_time", "")), fieldColumn(items, "hash", ""));
end

function plan = toPlanTable(items)
% toPlanTable - Plan table of the plan rows of a fixture
    items = toCell(items);
    plan = table(fieldColumn(items, "path", ""), fieldColumn(items, "action", ""), ...
        fieldColumn(items, "reason", ""), fieldColumn(items, "bytes", 0), ...
        'VariableNames', ["Path", "Action", "Reason", "Bytes"]);
end

function times = parseTimes(texts)
% parseTimes - Times of the fixtures, such as "2024-01-02T03:04:05Z", as datetimes in UTC
%
%   An empty text, which stands for null, gives NaT. The test reads the
%   times itself, so that the expected tables do not depend on the parser
%   of the toolbox that the manifest fixtures test.
    times = NaT(size(texts), TimeZone="UTC");
    isGiven = texts ~= "";
    if any(isGiven)
        times(isGiven) = datetime(texts(isGiven), InputFormat="yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone="UTC");
    end
end
