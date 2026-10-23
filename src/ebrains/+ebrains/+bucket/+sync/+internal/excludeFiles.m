function files = excludeFiles(files, patterns, options)
% excludeFiles - Leave out the files that match exclude patterns
%
%   files = ebrains.bucket.sync.internal.excludeFiles(files, patterns) removes
%   the rows of a file table whose Path matches any of the patterns. The
%   patterns are wildcard patterns, with the meaning they have in a
%   .gitignore file:
%       *   matches any characters except "/"
%       ?   matches one character except "/"
%       **  between separators matches any number of folders, none
%           included: "**/cache" matches "cache" at the root as well as
%           "a/cache", "a/**/b" matches "a/b" as well as "a/x/y/b", and
%           "a/**" matches everything below "a". Elsewhere "**" matches
%           any characters, "/" included.
%
%   A pattern without "/" is matched against every part of a path, so
%   "*.tmp" leaves out such files in every folder and ".git" leaves out a
%   folder of that name with everything in it. A pattern with "/" inside
%   it or in front of it is matched against the path from the root of the
%   synced folder, and also leaves out what is below a folder it matches:
%   "raw/scratch" leaves out "raw/scratch/a.dat", and "/build" leaves out
%   the "build" folder at the root but not "sub/build". A trailing "/" is
%   ignored, so ".git/" and "build/" leave out those folders wherever they
%   are.
%
%   files = ebrains.bucket.sync.internal.excludeFiles(..., IgnoreCase=true)
%   matches the patterns without regard to case, for a folder whose file
%   system ignores the case of names.
%
%   See also ebrains.bucket.sync.internal.planSync

    arguments
        files table
        patterns string
        options.IgnoreCase (1,1) logical = false
    end

    isExcluded = false(height(files), 1);
    for pattern = reshape(patterns, 1, [])
        trimmedPattern = regexprep(pattern, "^/+|/+$", "");
        if strlength(trimmedPattern) == 0
            continue
        end
        isAnchored = startsWith(pattern, "/") || contains(trimmedPattern, "/");
        isExcluded = isExcluded | matches(files.Path, ...
            patternToRegexp(trimmedPattern, isAnchored), IgnoreCase=options.IgnoreCase);
    end
    files = files(~isExcluded, :);
end

function expression = patternToRegexp(pattern, isAnchored)
% patternToRegexp - Regular expression of a wildcard pattern
%
%   The forms of "**" are swapped for placeholders before the single "*"
%   is translated, so that the two do not interfere, and put back as the
%   last step.

    anyFolders = char(1);   % "**/" at the start or "/**/" inside: zero or more folders
    anyBelow = char(2);     % "/**" at the end: anything below the folder
    anyText = char(3);      % "**" elsewhere

    expression = regexprep(pattern, "([.+^$(){}\[\]|\\])", "\\$1");
    expression = replace(expression, "/**/", "/" + anyFolders);
    expression = regexprep(expression, "^\*\*/", anyFolders);
    expression = regexprep(expression, "/\*\*$", anyBelow);
    expression = replace(expression, "**", anyText);
    expression = replace(expression, "*", "[^/]*");
    expression = replace(expression, "?", "[^/]");
    expression = replace(expression, anyFolders, "(.*/)?");
    expression = replace(expression, anyBelow, "(/.*)?");
    expression = replace(expression, anyText, ".*");

    if isAnchored
        expression = expression + "(/.*)?";
    else
        expression = "(.*/)?" + expression + "(/.*)?";
    end
    expression = regexpPattern(expression);
end
