function files = listLocalFiles(rootFolder)
% listLocalFiles - List the files below a local folder for a sync
%
%   files = ebrains.bucket.internal.listLocalFiles(rootFolder) returns a
%   table with one row per file in rootFolder and its subfolders, with the
%   variables Path, Bytes, ModifiedTime and Hash of
%   ebrains.bucket.internal.makeFileTable. Paths are relative to
%   rootFolder and use "/" as separator on every platform, as object names
%   do. Folders are not listed: an object store has no empty folders to
%   sync them to. The checksums are left unknown, since computing them
%   means reading every file.
%
%   A folder that does not exist has no files, so the table is empty.
%
%   See also ebrains.bucket.internal.listRemoteFiles, ebrains.bucket.internal.computeMd5

    arguments
        rootFolder (1,1) string
    end

    if ~isfolder(rootFolder)
        files = ebrains.bucket.internal.makeFileTable(strings(0, 1), zeros(0, 1));
        return
    end

    % The folder of each entry is absolute, so the absolute path of the
    % root is taken from the listing too rather than worked out here,
    % which could differ from what dir reports, for example through
    % symbolic links.
    rootListing = dir(rootFolder);
    rootEntry = rootListing(strcmp({rootListing.name}, '.'));
    absoluteRoot = string(rootEntry(1).folder);

    listing = dir(fullfile(rootFolder, "**", "*"));
    listing = listing(~[listing.isdir]);

    names = reshape(string({listing.name}), [], 1);
    folders = reshape(string({listing.folder}), [], 1);

    relativeFolders = extractAfter(folders, strlength(absoluteRoot));
    relativeFolders = replace(relativeFolders, "\", "/");
    relativeFolders = regexprep(relativeFolders, "^/+", "");

    paths = names;
    isInSubfolder = relativeFolders ~= "";
    paths(isInSubfolder) = relativeFolders(isInSubfolder) + "/" + names(isInSubfolder);

    % dir reports the modification time as a datenum in local time
    modifiedTimes = datetime(reshape([listing.datenum], [], 1), ...
        'ConvertFrom', 'datenum', 'TimeZone', 'local');

    files = ebrains.bucket.internal.makeFileTable(paths, [listing.bytes], modifiedTimes);
end
