function fileList = listSourceFiles()
% listSourceFiles - List the toolbox's own source files for analysis and coverage
%
%   fileList = ebtools.listSourceFiles() returns the full paths of the .m
%   files below src/ebrains, without those that match a prefix listed in
%   tools/.coverageignore. Prefixes are matched against the path relative
%   to src/ebrains, with "/" as separator on every platform. Empty lines
%   and lines starting with "#" in the ignore file are skipped.

    projectRootDirectory = ebtools.projectdir();
    sourceFolder = fullfile(projectRootDirectory, "src", "ebrains");

    listing = dir(fullfile(sourceFolder, "**", "*.m"));
    fileList = fullfile(string({listing.folder}'), string({listing.name}'));

    relativePaths = erase(fileList, sourceFolder + filesep);
    relativePaths = replace(relativePaths, filesep, "/");

    ignoreFile = fullfile(projectRootDirectory, "tools", ".coverageignore");
    ignorePrefixes = strtrim(string(splitlines(fileread(ignoreFile))));
    ignorePrefixes(ignorePrefixes == "" | startsWith(ignorePrefixes, "#")) = [];

    if ~isempty(ignorePrefixes)
        fileList(startsWith(relativePaths, ignorePrefixes)) = [];
    end
end
