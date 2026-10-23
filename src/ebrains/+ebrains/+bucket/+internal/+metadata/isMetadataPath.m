function tf = isMetadataPath(paths)
% isMetadataPath - Find the paths that are the .ebrains folder or below it
%
%   tf = ebrains.bucket.internal.metadata.isMetadataPath(paths) returns a
%   logical array of the size of paths that is true for ".ebrains" and
%   every path below it. Paths are relative to the root of a synced folder,
%   with "/" separators. Such paths are left out of both sides of every
%   sync, so the folder is never uploaded, downloaded or deleted. Case is
%   ignored, since on a file system that ignores it an object named
%   ".EBRAINS/..." would be written into the .ebrains folder.

    arguments
        paths string
    end

    name = ebrains.bucket.internal.metadata.folderName();
    tf = strcmpi(paths, name) | startsWith(paths, name + "/", IgnoreCase=true);
end
