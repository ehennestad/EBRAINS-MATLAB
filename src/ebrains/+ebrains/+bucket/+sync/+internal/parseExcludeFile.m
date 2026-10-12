function patterns = parseExcludeFile(text)
% parseExcludeFile - Exclude patterns of the text of an exclude file
%
%   patterns = ebrains.bucket.sync.internal.parseExcludeFile(text) returns
%   the patterns of an exclude file, one per line, in order, as a string
%   column vector. The file has the layout of a .gitignore file:
%       - Lines end with LF, CRLF or CR.
%       - A byte order mark at the start of the text, and spaces and tabs
%         around a line, are removed.
%       - Blank lines and lines that start with "#" are skipped. A "#"
%         later in a line is part of the pattern.
%       - A line that starts with "!" re-includes paths in a .gitignore
%         file, which exclude patterns cannot do. Such a line raises an
%         error naming it, since skipping it would silently leave out the
%         files the author meant to sync.
%
%   The rules are those of the spec of the ebrains-bucket-sync Python
%   package, which this function and that package both follow.
%
%   See also ebrains.bucket.sync.internal.readExcludeFile,
%   ebrains.bucket.sync.internal.excludeFiles

    arguments
        text (1,1) string
    end

    byteOrderMark = string(char(65279));
    if startsWith(text, byteOrderMark)
        text = extractAfter(text, 1);
    end

    lines = reshape(regexp(text, "\r\n|\r|\n", "split"), [], 1);
    lines = regexprep(lines, "^[ \t]+|[ \t]+$", "");

    isNegation = startsWith(lines, "!");
    if any(isNegation)
        lineNumber = find(isNegation, 1);
        error('EBRAINS:Bucket:Sync:ExcludeFileNegation', ...
            ['Line %d ("%s") starts with "!", which re-includes paths in a .gitignore file. ' ...
             'Exclude patterns cannot do that. Remove the line, or exclude the other ' ...
             'paths more precisely.'], lineNumber, lines(lineNumber));
    end

    isPattern = lines ~= "" & ~startsWith(lines, "#");
    patterns = lines(isPattern);
end
