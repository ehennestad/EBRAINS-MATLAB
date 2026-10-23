function files = listLocalFile(rootFolder, relativePath)
% listLocalFile - List one file below a local folder, as listLocalFiles lists all of them
%
%   files = ebrains.bucket.sync.internal.listLocalFile(rootFolder, relativePath)
%   returns a file table of ebrains.bucket.sync.internal.makeFileTable with
%   one row for the file at relativePath below rootFolder, with the Path,
%   Bytes and ModifiedTime that ebrains.bucket.sync.internal.listLocalFiles
%   gives it, and no rows if the path is not a file: a folder, or a file
%   that does not exist. The checksum is left unknown. An action that
%   judges a file must read it as it is now, and this reads one file
%   without walking the folder, which may stand for a bucket of many
%   objects.
%
%   Path is relativePath as given. On a file system that ignores case the
%   file may be stored under another case, as a local file matched to an
%   object of the same name in another case is, and it is read all the
%   same.
%
%   See also ebrains.bucket.sync.internal.listLocalFiles

    arguments
        rootFolder (1,1) string
        relativePath (1,1) string
    end

    files = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
    filePath = fullfile(rootFolder, relativePath);
    if ~isfile(filePath)
        return
    end

    % dir expands wildcards in a name, so only the entry of this name
    % counts. Where the file system ignores case, dir reports the name as
    % stored, which may differ in case from the one asked for, so an entry
    % of the same name in another case is taken when none matches exactly.
    listing = dir(filePath);
    [~, name, extension] = fileparts(filePath);
    names = string({listing.name});
    isEntry = ~[listing.isdir] & names == name + extension;
    if ~any(isEntry)
        isEntry = ~[listing.isdir] & strcmpi(names, name + extension);
    end
    listing = listing(isEntry);
    if isempty(listing)
        return
    end

    absolutePath = string(fullfile(listing(1).folder, listing(1).name));
    modifiedTime = ebrains.bucket.sync.internal.fileModifiedTimes(absolutePath, listing(1).datenum);
    files = ebrains.bucket.sync.internal.makeFileTable(relativePath, listing(1).bytes, modifiedTime);
end
