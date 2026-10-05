function files = listLocalFiles(rootFolder)
% listLocalFiles - List the files below a local folder for a sync
%
%   files = ebrains.bucket.sync.internal.listLocalFiles(rootFolder) returns a
%   table with one row per file in rootFolder and its subfolders, with the
%   variables Path, Bytes, ModifiedTime and Hash of
%   ebrains.bucket.sync.internal.makeFileTable. Paths are relative to
%   rootFolder and use "/" as separator on every platform, as object names
%   do. Folders are not listed: an object store has no empty folders to
%   sync them to. The checksums are left unknown, since computing them
%   means reading every file.
%
%   A folder that does not exist has no files, so the table is empty.
%
%   See also ebrains.bucket.sync.internal.listRemoteFiles, ebrains.bucket.sync.internal.computeMD5

    arguments
        rootFolder (1,1) string
    end

    if ~isfolder(rootFolder)
        files = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
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

    modifiedTimes = fileModifiedTimes(fullfile(folders, names), reshape([listing.datenum], [], 1));

    files = ebrains.bucket.sync.internal.makeFileTable(paths, [listing.bytes], modifiedTimes);
end

function modifiedTimes = fileModifiedTimes(absolutePaths, datenums)
% fileModifiedTimes - Modification time of each file, in UTC
%
%   dir reports the time as a datenum in local wall-clock time, which is
%   ambiguous for the hour that repeats when daylight saving time ends.
%   The file system holds the time as an instant, which Java reads as
%   milliseconds since the epoch, so that is used where Java is available.
%   The paths are absolute: Java resolves a relative path against its own
%   working directory, which need not be MATLAB's.

    if usejava('jvm')
        epochMilliseconds = zeros(numel(absolutePaths), 1);
        for i = 1:numel(absolutePaths)
            epochMilliseconds(i) = java.io.File(char(absolutePaths(i))).lastModified();
        end
        modifiedTimes = datetime(epochMilliseconds / 1000, ...
            'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        % lastModified gives 0 for a file that vanished since the listing
        modifiedTimes(epochMilliseconds == 0) = NaT;
    else
        modifiedTimes = datetime(datenums, 'ConvertFrom', 'datenum', 'TimeZone', 'local');
    end
end
