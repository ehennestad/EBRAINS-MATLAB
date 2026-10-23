function files = parseManifest(text)
% parseManifest - File table of the text of a manifest.csv
%
%   files = ebrains.bucket.internal.metadata.parseManifest(text) reads
%   the text that ebrains.bucket.internal.metadata.formatManifest writes
%   and returns a file table (see ebrains.bucket.sync.internal.makeFileTable).
%   Text that does not start with the header
%   "path,bytes,modified_time,hash", or whose lines do not have four
%   fields, is an error.

    arguments
        text (1,1) string
    end

    header = "path,bytes,modified_time,hash" + newline;
    if ~startsWith(text, header)
        error('EBRAINS:Bucket:InvalidManifest', ...
            'A manifest must start with the line "path,bytes,modified_time,hash".')
    end
    body = char(extractAfter(text, strlength(header)));

    if isempty(body)
        files = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
        return
    end
    if body(end) ~= newline
        body(end + 1) = newline;
    end

    % Every field ends with a comma, or with the line break that ends its
    % line. A quoted field may hold commas, line breaks and doubled quotes.
    [parts, starts, ends] = regexp(body, ...
        '(?<field>"(?:[^"]|"")*"|[^,"\n]*)(?<separator>,|\n)', 'names', 'start', 'end');
    isContiguous = ~isempty(ends) && starts(1) == 1 && ends(end) == numel(body) ...
        && all(starts(2:end) == ends(1:end-1) + 1);
    separators = [parts.separator];
    nFields = numel(parts);
    if ~isContiguous || mod(nFields, 4) ~= 0 ...
            || ~all(reshape(separators, 4, []) == [',', ',', ',', newline]', "all")
        error('EBRAINS:Bucket:InvalidManifest', ...
            'The manifest is not in the form path,bytes,modified_time,hash on every line.')
    end

    fields = reshape(string({parts.field}), 4, [])';
    isQuoted = startsWith(fields(:, 1), """");
    fields(isQuoted, 1) = replace(extractBetween(fields(isQuoted, 1), 2, ...
        strlength(fields(isQuoted, 1)) - 1), """""", """");

    files = ebrains.bucket.sync.internal.makeFileTable(fields(:, 1), str2double(fields(:, 2)), ...
        ebrains.bucket.internal.metadata.parseTimes(fields(:, 3)), fields(:, 4));
end
