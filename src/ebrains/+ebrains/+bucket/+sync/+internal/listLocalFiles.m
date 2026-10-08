function [files, unreadableFolders] = listLocalFiles(rootFolder)
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
%   [files, unreadableFolders] = ebrains.bucket.sync.internal.listLocalFiles(rootFolder)
%   also returns the subfolders that could not be read, as a string column
%   of paths in the same form. dir leaves out the files of such a folder
%   without an error, so the table lacks them, and a caller that deletes
%   what the table lacks must check this output first.
%
%   A folder that does not exist has no files, so the table is empty. A
%   root folder that cannot be read is an error.
%
%   See also ebrains.bucket.sync.internal.listRemoteFiles, ebrains.bucket.sync.internal.computeMD5

    arguments
        rootFolder (1,1) string
    end

    if ~isfolder(rootFolder)
        files = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
        unreadableFolders = strings(0, 1);
        return
    end

    % The folder of each entry is absolute, so the absolute path of the
    % root is taken from the listing too rather than worked out here,
    % which could differ from what dir reports, for example through
    % symbolic links. A folder that cannot be read lists nothing.
    rootListing = dir(rootFolder);
    if isempty(rootListing)
        error('EBRAINS:Bucket:Sync:UnreadableFolder', ...
            'The folder "%s" could not be read. Check that you have permission to read it.', ...
            rootFolder)
    end
    rootEntry = rootListing(strcmp({rootListing.name}, '.'));
    absoluteRoot = string(rootEntry(1).folder);

    listing = dir(fullfile(rootFolder, "**", "*"));
    names = reshape(string({listing.name}), [], 1);
    folders = reshape(string({listing.folder}), [], 1);
    isFolderEntry = reshape([listing.isdir], [], 1);

    % Every folder whose content dir could read has a "." entry in the
    % listing. A subfolder without one could not be read.
    readFolders = folders(names == ".");
    isSubfolder = isFolderEntry & names ~= "." & names ~= "..";
    subfolders = fullfile(folders(isSubfolder), names(isSubfolder));
    unreadableFolders = toRelativePaths(subfolders(~ismember(subfolders, readFolders)), absoluteRoot);

    isFile = ~isFolderEntry;
    absolutePaths = fullfile(folders(isFile), names(isFile));
    paths = toRelativePaths(absolutePaths, absoluteRoot);

    modifiedTimes = fileModifiedTimes(absolutePaths, reshape([listing(isFile).datenum], [], 1));

    files = ebrains.bucket.sync.internal.makeFileTable(paths, [listing(isFile).bytes], modifiedTimes);
end

function relativePaths = toRelativePaths(absolutePaths, absoluteRoot)
% toRelativePaths - Paths below a root, relative to it and with "/" separators
    relativePaths = extractAfter(absolutePaths, strlength(absoluteRoot));
    relativePaths = replace(relativePaths, "\", "/");
    relativePaths = regexprep(relativePaths, "^/+", "");
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
