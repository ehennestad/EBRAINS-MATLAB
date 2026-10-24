function [files, unreadableFolders, linkedFolders] = listLocalFiles(rootFolder)
% listLocalFiles - List the files below a local folder for a sync
%
%   files = ebrains.bucket.sync.internal.listLocalFiles(rootFolder) returns a
%   table with one row per file in rootFolder and its subfolders, with the
%   variables Path, Bytes, ModifiedTime and Hash of
%   ebrains.bucket.sync.internal.makeFileTable. Paths are relative to
%   rootFolder and use "/" as separator on every platform, as object names
%   do. Folders are not listed: an object store has no empty folders to
%   sync them to. The .ebrains folder of a virtual bucket and the files
%   below it are left out, and so are the files of interrupted transfers
%   (see ebrains.bucket.sync.internal.isTransferLeftover). The checksums
%   are left unknown, since computing them means reading every file.
%
%   [files, unreadableFolders] = ebrains.bucket.sync.internal.listLocalFiles(rootFolder)
%   also returns the subfolders that could not be read, as a string column
%   of paths in the same form. dir leaves out the files of such a folder
%   without an error, so the table lacks them, and a caller that deletes
%   what the table lacks must check this output first.
%
%   [files, unreadableFolders, linkedFolders] = ebrains.bucket.sync.internal.listLocalFiles(rootFolder)
%   also returns the subfolders that are symbolic links, in the same form.
%   Their content is not listed: it is stored outside rootFolder, where a
%   sync must not delete files, and a caller that deletes what the table
%   lacks must check this output too. Links are found with Java; without
%   it, linked folders are listed as ordinary folders.
%
%   A folder that does not exist has no files, so the table is empty. A
%   root folder that cannot be read is an error.
%
%   See also ebrains.bucket.sync.internal.listLocalFile, ebrains.bucket.sync.internal.listRemoteFiles,
%   ebrains.bucket.sync.internal.computeMD5

    arguments
        rootFolder (1,1) string
    end

    if ~isfolder(rootFolder)
        files = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
        unreadableFolders = strings(0, 1);
        linkedFolders = strings(0, 1);
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

    % dir follows a linked folder, so the entries below one are dropped
    isSubfolder = isFolderEntry & names ~= "." & names ~= "..";
    subfolders = fullfile(folders(isSubfolder), names(isSubfolder));
    linkedAbsolute = subfolders(isSymbolicLink(subfolders));
    isBelowLink = false(size(folders));
    for linkedFolder = reshape(linkedAbsolute, 1, [])
        isBelowLink = isBelowLink | folders == linkedFolder | startsWith(folders, linkedFolder + filesep);
    end
    listing = listing(~isBelowLink);
    names = names(~isBelowLink);
    folders = folders(~isBelowLink);
    isFolderEntry = isFolderEntry(~isBelowLink);
    linkedFolders = toRelativePaths(linkedAbsolute, absoluteRoot);

    % Every folder whose content dir could read has a "." entry in the
    % listing. A subfolder without one could not be read.
    readFolders = folders(names == ".");
    isSubfolder = isFolderEntry & names ~= "." & names ~= "..";
    subfolders = fullfile(folders(isSubfolder), names(isSubfolder));
    isUnread = ~ismember(subfolders, readFolders) & ~ismember(subfolders, linkedAbsolute);
    unreadableFolders = toRelativePaths(subfolders(isUnread), absoluteRoot);

    isFile = ~isFolderEntry;
    absolutePaths = fullfile(folders(isFile), names(isFile));
    paths = toRelativePaths(absolutePaths, absoluteRoot);

    modifiedTimes = ebrains.bucket.sync.internal.fileModifiedTimes( ...
        absolutePaths, reshape([listing(isFile).datenum], [], 1));

    files = ebrains.bucket.sync.internal.makeFileTable(paths, [listing(isFile).bytes], modifiedTimes);

    % The .ebrains folder describes the folder as a virtual bucket, and the
    % file of an interrupted transfer holds no data of its own. Neither is
    % part of what is synced.
    isLeftOut = ebrains.bucket.internal.metadata.isMetadataPath(files.Path) ...
        | ebrains.bucket.sync.internal.isTransferLeftover(files.Path);
    files = files(~isLeftOut, :);
    unreadableFolders = unreadableFolders(~ebrains.bucket.internal.metadata.isMetadataPath(unreadableFolders));
end

function tf = isSymbolicLink(absolutePaths)
% isSymbolicLink - Whether each path is a symbolic link, false for all without Java
    tf = false(size(absolutePaths));
    if ~usejava('jvm')
        return
    end
    for i = 1:numel(absolutePaths)
        tf(i) = java.nio.file.Files.isSymbolicLink(java.io.File(char(absolutePaths(i))).toPath());
    end
end

function relativePaths = toRelativePaths(absolutePaths, absoluteRoot)
% toRelativePaths - Paths below a root, relative to it and with "/" separators
%
%   Only the separator of the platform is replaced: on Linux and macOS a
%   backslash is an ordinary character of a name and stays.
    relativePaths = extractAfter(absolutePaths, strlength(absoluteRoot));
    relativePaths = replace(relativePaths, string(filesep), "/");
    relativePaths = regexprep(relativePaths, "^/+", "");
end
