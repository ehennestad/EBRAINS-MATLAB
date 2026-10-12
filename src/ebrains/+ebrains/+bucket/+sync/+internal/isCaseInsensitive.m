function tf = isCaseInsensitive(localFolder, localPaths)
% isCaseInsensitive - Whether the file system of a local folder ignores the case of names
%
%   tf = ebrains.bucket.sync.internal.isCaseInsensitive(localFolder,
%   localPaths) probes the file system with the files of a listing of the
%   folder: a listed file whose path has letters is looked up with their
%   case changed. A file system that ignores case finds it under that
%   path, and the listing has no file of that path. Without such a file
%   there is nothing to look up, and the default file systems of macOS and
%   Windows are taken to ignore case and those of other platforms not to.
%
%   On a file system that ignores case, a local file and an object whose
%   names differ only in case are one file: a download writes into the
%   local file and keeps its name.
%
%   See also ebrains.bucket.sync.internal.dropCaseCollisions

    arguments
        localFolder (1,1) string
        localPaths string
    end

    hasLetters = upper(localPaths) ~= lower(localPaths);
    index = find(hasLetters, 1);
    if isempty(index)
        tf = ismac || ispc;
        return
    end

    probePath = upper(localPaths(index));
    if probePath == localPaths(index)
        probePath = lower(localPaths(index));
    end
    tf = ~ismember(probePath, localPaths) && isfile(fullfile(localFolder, probePath));
end
