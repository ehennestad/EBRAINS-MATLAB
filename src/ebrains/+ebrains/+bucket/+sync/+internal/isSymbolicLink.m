function tf = isSymbolicLink(paths)
% isSymbolicLink - Whether each path is a symbolic link
%
%   tf = ebrains.bucket.sync.internal.isSymbolicLink(paths) returns a
%   logical array of the size of paths that is true for every path that
%   is a symbolic link. From R2024b, MATLAB's own isSymbolicLink tells a
%   link from what it points to. Before that MATLAB has no such function,
%   so Java does it, and without Java the result is false for every
%   path. Java resolves a relative path against its own working
%   directory, which need not be MATLAB's, so give absolute paths.
%
%   See also isSymbolicLink, ebrains.bucket.sync.internal.listLocalFiles,
%   ebrains.bucket.sync.internal.assertNotBelowLinkedFolder

    arguments
        paths string
    end

    tf = false(size(paths));
    if isempty(paths)
        return
    end

    if ~isMATLABReleaseOlderThan("R2024b")
        % The unqualified name is MATLAB's function: a function of a
        % namespace is reached only through the namespace, this one too
        tf = reshape(isSymbolicLink(paths), size(paths));
        return
    end

    if ~usejava('jvm')
        return
    end
    for i = 1:numel(paths)
        tf(i) = java.nio.file.Files.isSymbolicLink(java.io.File(char(paths(i))).toPath());
    end
end
