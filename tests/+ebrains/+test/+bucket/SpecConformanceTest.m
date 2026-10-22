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
        ExcludeFileFixture = fixtureFiles("exclude-file")
        RefusalFixture = fixtureFiles("refusal")
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

        function testExcludeFileFixture(testCase, ExcludeFileFixture)
            fixture = readFixture(ExcludeFileFixture);
            text = string(fixture.text);

            if isfield(fixture, "expected_error_line")
                % The error names the refused line by its number
                exception = MException.empty;
                try
                    ebrains.bucket.sync.internal.parseExcludeFile(text);
                catch exception
                end
                testCase.assertNotEmpty(exception, "The file is refused. " + fixture.description);
                testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:Sync:ExcludeFileNegation');
                testCase.verifyTrue(startsWith(exception.message, ...
                    sprintf("Line %d ", fixture.expected_error_line)), fixture.description);
            else
                patterns = ebrains.bucket.sync.internal.parseExcludeFile(text);
                testCase.verifyEqual(patterns, toStringColumn(fixture.expected_patterns), fixture.description);
            end
        end

        function testRefusalFixture(testCase, RefusalFixture)
            fixture = readFixture(RefusalFixture);
            % A null max_delete is no limit, and a null expected_code no refusal
            maxDelete = Inf;
            if ~isempty(fixture.max_delete)
                maxDelete = fixture.max_delete;
            end
            expectedIdentifier = "";
            if ~isempty(fixture.expected_code)
                expectedIdentifier = "EBRAINS:Bucket:Sync:" + fixture.expected_code;
            end

            identifier = ebrains.bucket.sync.internal.deletionRefusal( ...
                toPlanTable(fixture.plan), fixture.n_source_files, maxDelete);

            testCase.verifyEqual(identifier, expectedIdentifier, fixture.description);
        end

        function testManifestFixture(testCase, ManifestFixture)
            fixture = readFixture(ManifestFixture);
            text = string(fixture.text);

            if isfield(fixture, "expected_error_line")
                exception = MException.empty;
                try
                    ebrains.bucket.internal.metadata.parseManifest(text);
                catch exception
                end
                testCase.assertNotEmpty(exception, "The text is refused. " + fixture.description);
                testCase.verifyEqual(exception.identifier, 'EBRAINS:Bucket:InvalidManifest', fixture.description);
                testCase.verifyTrue(startsWith(exception.message, ...
                    sprintf("Line %d: ", fixture.expected_error_line)), ...
                    sprintf('The error names line %d: "%s". %s', fixture.expected_error_line, ...
                    exception.message, fixture.description));
                return
            end
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
            expectedStates = table(fieldColumn(expected, "path"), fieldColumn(expected, "state"), ...
                'VariableNames', ["Path", "State"]);
            testCase.verifyEqual(files(:, ["Path", "State"]), expectedStates, fixture.description);
        end

        function testPlaceholderFixture(testCase, PlaceholderFixture)
            fixture = readFixture(PlaceholderFixture);

            % A virtual bucket that was never listed (manifest null) has an
            % empty manifest, as ebrains.bucket.internal.metadata.readManifest
            % returns it, so null and an empty list are one case here.
            switch fixture.direction
                case "to_bucket"
                    placeholderRule = @ebrains.bucket.sync.internal.protectPlaceholders;
                case "from_bucket"
                    placeholderRule = @ebrains.bucket.sync.internal.deleteRemovedPlaceholders;
                otherwise
                    error('EBRAINS:Test:UnknownDirection', 'The direction "%s" is unknown.', fixture.direction)
            end
            plan = placeholderRule(toPlanTable(fixture.plan), toFileTable(fixture.local), ...
                toFileTable(fixture.listing), toFileTable(fixture.manifest));

            testCase.verifyEqual(plan, toPlanTable(fixture.expected), fixture.description);
        end

        function testManifestUpdateFixture(testCase, ManifestUpdateFixture)
            fixture = readFixture(ManifestUpdateFixture);

            manifest = ebrains.bucket.sync.internal.manifestAfterPush( ...
                toFileTable(fixture.listing), toFileTable(fixture.uploaded), ...
                toStringColumn(fixture.deleted), toFileTable(fixture.local), ...
                toFileTable(fixture.manifest));

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
%
%   Without a default the field is required, as the Python runner requires
%   it, so that a misspelled key fails rather than compare as a default.
    arguments
        items cell
        fieldName (1,1) string
        default = missing
    end
    isRequired = ismissing(default);
    if isRequired
        values = strings(numel(items), 1);
    else
        values = repmat(default, numel(items), 1);
    end
    for i = 1:numel(items)
        if isfield(items{i}, fieldName) && ~isempty(items{i}.(fieldName))
            values(i) = items{i}.(fieldName);
        elseif isRequired
            error('EBRAINS:Test:MissingFixtureField', 'An entry of the fixture has no "%s".', fieldName)
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
        fieldColumn(items, "path"), double(fieldColumn(items, "bytes")), ...
        parseTimes(fieldColumn(items, "modified_time", "")), fieldColumn(items, "hash", ""));
end

function plan = toPlanTable(items)
% toPlanTable - Plan table of the plan rows of a fixture
    items = toCell(items);
    plan = table(fieldColumn(items, "path"), fieldColumn(items, "action"), ...
        fieldColumn(items, "reason"), double(fieldColumn(items, "bytes")), ...
        'VariableNames', ["Path", "Action", "Reason", "Bytes"]);
end

function times = parseTimes(texts)
% parseTimes - Times of the fixtures, such as "2024-01-02T03:04:05Z", as datetimes in UTC
%
%   A time may have a fraction of a second, and an offset such as
%   "+02:00" in place of "Z", as the Python runner reads them. An empty
%   text, which stands for null, gives NaT. The test reads the times
%   itself, so that the expected tables do not depend on the parser of the
%   toolbox that the manifest fixtures test.
    pattern = "^(?<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?<fraction>(\.\d+)?)" + ...
        "(?<zone>Z|[+-]\d{2}:\d{2})$";
    times = NaT(size(texts), TimeZone="UTC");
    for i = reshape(find(texts ~= ""), 1, [])
        parts = regexp(texts(i), pattern, "names", "once");
        if isempty(parts)
            error('EBRAINS:Test:InvalidFixtureTime', 'The time "%s" of a fixture is not ISO 8601.', texts(i))
        end
        time = datetime(parts.time, InputFormat="yyyy-MM-dd'T'HH:mm:ss", TimeZone="UTC");
        if parts.fraction ~= ""
            time = time + seconds(str2double("0" + parts.fraction));
        end
        if parts.zone ~= "Z"
            offset = hours(str2double(extractBetween(parts.zone, 2, 3))) + ...
                minutes(str2double(extractBetween(parts.zone, 5, 6)));
            if startsWith(parts.zone, "-")
                offset = -offset;
            end
            time = time - offset;
        end
        times(i) = time;
    end
end
