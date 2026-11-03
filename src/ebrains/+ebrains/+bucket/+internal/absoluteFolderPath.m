function absolutePath = absoluteFolderPath(folder)
% absoluteFolderPath - Absolute path of an existing folder, as the operating system writes it
%
%   absolutePath = ebrains.bucket.internal.absoluteFolderPath(folder)
%   resolves a relative path against the current folder. A folder that
%   does not exist is an error (EBRAINS:Bucket:FolderNotFound).

    arguments
        folder (1,1) string
    end

    listing = dir(folder);
    isSelf = strcmp({listing.name}, '.');
    if ~any(isSelf)
        error('EBRAINS:Bucket:FolderNotFound', '"%s" is not a folder.', folder)
    end
    absolutePath = string(listing(isSelf).folder);
end
