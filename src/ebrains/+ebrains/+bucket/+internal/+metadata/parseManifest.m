function files = parseManifest(text)
% parseManifest - File table of the text of a manifest.csv
%
%   files = ebrains.bucket.internal.metadata.parseManifest(text) reads
%   the text that ebrains.bucket.internal.metadata.formatManifest writes
%   and returns a file table (see ebrains.bucket.sync.internal.makeFileTable).
%
%   Text that does not follow the layout of spec/README.md#virtual-buckets
%   of the ebrains-bucket-sync package raises EBRAINS:Bucket:InvalidManifest
%   at the first line that breaks it, with a message that starts
%   "Line <n>: ". A row is refused rather than skipped, since a missing
%   entry could let a placeholder replace its object. Refused are: a first
%   line other than the header "path,bytes,modified_time,hash", a row that
%   is not CSV text or does not have four fields (an empty line included),
%   a path that is empty, does not stay below the folder or is on an
%   earlier row, bytes that are not digits, a modified_time that is
%   neither empty nor a time written as "2024-01-02T03:04:05Z", and a hash
%   that is neither empty nor 32 lowercase hexadecimal digits. Lines may
%   end with LF or CR LF, and the last line may lack its line end. A row
%   that spans lines is counted at the line where it starts.
%
%   See also ebrains.bucket.internal.metadata.readManifest

    arguments
        text (1,1) string
    end

    [rows, rowLines] = splitRows(char(text));

    header = ["path", "bytes", "modified_time", "hash"];
    if isempty(rows) || ~isequal(rows{1}, header)
        invalid(1, 'the first line is not the header "path,bytes,modified_time,hash"')
    end

    entryRows = rows(2:end);
    entryLines = rowLines(2:end);

    % A row without four fields cannot be read further, so the other rules
    % are checked on the rows before the first such row, and the first
    % line that breaks any rule is the one reported.
    nFields = cellfun(@numel, entryRows);
    firstShortRow = find(nFields ~= numel(header), 1);
    if isempty(firstShortRow)
        firstShortRow = numel(entryRows) + 1;
    end
    fields = reshape(string([entryRows{1:firstShortRow-1}]), numel(header), [])';
    if isempty(fields)
        fields = strings(0, numel(header));
    end
    paths = fields(:, 1);
    times = fields(:, 3);
    hashes = fields(:, 4);

    [~, firstOccurrence] = unique(paths, 'stable');
    isRepeated = true(size(paths));
    isRepeated(firstOccurrence) = false;
    problems = [ ...
        ~ebrains.bucket.internal.isSafeRelativePath(paths), ...
        ~matches(fields(:, 2), regexpPattern("[0-9]+")), ...
        times ~= "" & ~ebrains.bucket.internal.metadata.isTimeText(times), ...
        hashes ~= "" & ~matches(hashes, regexpPattern("[0-9a-f]{32}")), ...
        isRepeated];
    firstBadRow = find(any(problems, 2), 1);

    if ~isempty(firstBadRow)
        line = entryLines(firstBadRow);
        row = fields(firstBadRow, :);
        descriptions = [ ...
            string(sprintf('the path "%s" does not stay below the folder', row(1))), ...
            string(sprintf('bytes "%s" is not a whole number', row(2))), ...
            string(sprintf('modified_time "%s" is neither empty nor a time in UTC', row(3))), ...
            string(sprintf('hash "%s" is neither empty nor a lowercase MD5 checksum', row(4))), ...
            string(sprintf('the path "%s" is on an earlier line', row(1)))];
        invalid(line, descriptions(find(problems(firstBadRow, :), 1)))
    elseif firstShortRow <= numel(entryRows)
        invalid(entryLines(firstShortRow), sprintf('it has %d fields, not %d', ...
            nFields(firstShortRow), numel(header)))
    end

    files = ebrains.bucket.sync.internal.makeFileTable(paths, str2double(fields(:, 2)), ...
        ebrains.bucket.internal.metadata.parseTimes(times), hashes);
end

function [rows, rowLines] = splitRows(chars)
% splitRows - Fields of each row of CSV text, and the line each row starts on
%
%   A field in double quotes may hold commas, line breaks and doubled
%   double quotes. A double quote anywhere else is an error, as is text
%   after the closing quote of a field. An empty line is a row of one
%   empty field.

    if ~any(chars == '"')
        [rows, rowLines] = splitUnquotedRows(chars);
        return
    end

    rows = {};
    rowLines = zeros(1, 0);
    nChars = numel(chars);
    position = 1;
    line = 1;
    while position <= nChars
        rowStartLine = line;
        fields = strings(1, 0);
        isRowEnd = false;
        while ~isRowEnd
            if position <= nChars && chars(position) == '"'
                [field, position, line] = readQuotedField(chars, position, line, rowStartLine);
            else
                fieldStart = position;
                while position <= nChars && ~any(chars(position) == [',', newline, char(13), '"'])
                    position = position + 1;
                end
                if position <= nChars && chars(position) == '"'
                    invalid(rowStartLine, 'it is not a row of CSV text (a double quote inside an unquoted field)')
                end
                field = string(chars(fieldStart:position-1));
            end
            fields(end + 1) = field; %#ok<AGROW>

            if position > nChars
                isRowEnd = true;
            elseif chars(position) == ','
                position = position + 1;
            elseif chars(position) == newline
                position = position + 1;
                line = line + 1;
                isRowEnd = true;
            elseif chars(position) == char(13) && position < nChars && chars(position + 1) == newline
                position = position + 2;
                line = line + 1;
                isRowEnd = true;
            else
                invalid(rowStartLine, 'it is not a row of CSV text (text after a quoted field, or a lone carriage return)')
            end
        end
        rows{end + 1} = fields; %#ok<AGROW>
        rowLines(end + 1) = rowStartLine; %#ok<AGROW>
    end
end

function [rows, rowLines] = splitUnquotedRows(chars)
% splitUnquotedRows - splitRows for text without double quotes, where every line is a row
%
%   Most manifests quote no field, and splitting on line ends and commas
%   reads a manifest of many rows much faster than a pass over each
%   character.
    lines = split(string(chars), newline);
    if lines(end) == ""
        lines(end) = []; % the line end of the last line
    end
    lines = reshape(lines, 1, []);
    hasCarriageReturn = endsWith(lines, char(13));
    lines(hasCarriageReturn) = extractBefore(lines(hasCarriageReturn), strlength(lines(hasCarriageReturn)));
    loneReturn = find(contains(lines, char(13)), 1);
    if ~isempty(loneReturn)
        invalid(loneReturn, 'it is not a row of CSV text (a lone carriage return)')
    end
    rows = arrayfun(@(line) reshape(split(line, ","), 1, []), lines, 'UniformOutput', false);
    rowLines = 1:numel(lines);
end

function [field, position, line] = readQuotedField(chars, position, line, rowStartLine)
% readQuotedField - The text of a field in double quotes, which starts at position
    nChars = numel(chars);
    position = position + 1;
    parts = '';
    while true
        if position > nChars
            invalid(rowStartLine, 'it is not a row of CSV text (a quoted field is not closed)')
        end
        character = chars(position);
        if character == '"'
            if position < nChars && chars(position + 1) == '"'
                parts(end + 1) = '"'; %#ok<AGROW>
                position = position + 2;
            else
                position = position + 1;
                break
            end
        else
            if character == newline
                line = line + 1;
            end
            parts(end + 1) = character; %#ok<AGROW>
            position = position + 1;
        end
    end
    field = string(parts);
end

function invalid(line, problem)
% invalid - Raise the error of a manifest that breaks the layout at a line
    error('EBRAINS:Bucket:InvalidManifest', 'Line %d: %s.', line, problem)
end
