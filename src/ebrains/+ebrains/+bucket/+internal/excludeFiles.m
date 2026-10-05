function files = excludeFiles(files, patterns)
% excludeFiles - Leave out the files that match exclude patterns
%
%   files = ebrains.bucket.internal.excludeFiles(files, patterns) removes
%   the rows of a file table whose Path matches any of the patterns. The
%   patterns are wildcard patterns:
%       *   matches any characters except "/"
%       **  matches any characters, "/" included
%       ?   matches one character except "/"
%
%   A pattern without "/" is matched against every part of a path, so
%   "*.tmp" leaves out such files in every folder and ".git" leaves out a
%   folder of that name with everything in it. A pattern with "/" is
%   matched against the path from the root of the synced folder, and also
%   leaves out what is below a folder it matches: "raw/scratch" leaves out
%   "raw/scratch/a.dat". A leading or trailing "/" is ignored, so ".git/"
%   and "build/" leave out those folders wherever they are, as in a
%   .gitignore file.
%
%   See also ebrains.bucket.internal.planSync

    arguments
        files table
        patterns string
    end

    isExcluded = false(height(files), 1);
    for pattern = reshape(patterns, 1, [])
        pattern = regexprep(pattern, "^/+|/+$", "");
        if strlength(pattern) == 0
            continue
        end
        isExcluded = isExcluded | matches(files.Path, patternToRegexp(pattern));
    end
    files = files(~isExcluded, :);
end

function expression = patternToRegexp(pattern)

    isAnchored = contains(pattern, "/");

    expression = regexprep(pattern, "([.+^$(){}\[\]|\\])", "\\$1");
    expression = replace(expression, "**", char(0));
    expression = replace(expression, "*", "[^/]*");
    expression = replace(expression, "?", "[^/]");
    expression = replace(expression, char(0), ".*");

    if isAnchored
        expression = expression + "(/.*)?";
    else
        expression = "(.*/)?" + expression + "(/.*)?";
    end
    expression = regexpPattern(expression);
end
