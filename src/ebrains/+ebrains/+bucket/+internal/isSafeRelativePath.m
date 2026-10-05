function tf = isSafeRelativePath(paths)
% isSafeRelativePath - Whether object names can be used as paths below a folder
%
%   tf = ebrains.bucket.internal.isSafeRelativePath(paths) is true for
%   the names that stay below the folder they are joined to with fullfile,
%   and false for the ones that could leave it or point elsewhere: a name
%   with a "." or ".." segment, an empty segment (a leading, trailing or
%   doubled "/"), or a backslash, which Windows reads as a separator.
%   Object names come from the bucket, which other members of a collab
%   can write to, so a sync must not trust them to be plain paths.
%
%   See also ebrains.bucket.internal.listRemoteFiles, ebrains.bucket.createVirtualBucket

    arguments
        paths string
    end

    tf = true(size(paths));
    for i = 1:numel(paths)
        segments = split(paths(i), "/");
        tf(i) = ~any(segments == "" | segments == "." | segments == "..") ...
            && ~contains(paths(i), "\");
    end
end
