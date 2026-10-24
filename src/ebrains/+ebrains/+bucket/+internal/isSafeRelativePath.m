function tf = isSafeRelativePath(paths)
% isSafeRelativePath - Whether object names can be used as paths below a folder
%
%   tf = ebrains.bucket.internal.isSafeRelativePath(paths) is true for
%   the names that stay below the folder they are joined to with fullfile,
%   and false for the ones that could leave it or point elsewhere: a name
%   with a "." or ".." segment, an empty segment (a leading, trailing or
%   doubled "/"), a backslash, which Windows reads as a separator, or a
%   Windows drive such as "C:" as its first segment, which makes the name
%   absolute on Windows. Object names come from the bucket, which other
%   members of a collab can write to, so they must not be trusted to be
%   plain paths. The rule is that of the sync contract shared with the
%   ebrains-bucket-sync package (spec/README.md#file-entries), so that
%   both tools leave out the same objects.
%
%   See also ebrains.bucket.createVirtualBucket

    arguments
        paths string
    end

    % A drive is a letter and ":" at the start of the name, with or without
    % a "/" after it: "C:/x" and "c:x" both name a path on drive C on Windows.
    drivePattern = regexpPattern("[A-Za-z]:");

    tf = true(size(paths));
    for i = 1:numel(paths)
        segments = split(paths(i), "/");
        tf(i) = ~any(segments == "" | segments == "." | segments == "..") ...
            && ~contains(paths(i), "\") ...
            && ~startsWith(paths(i), drivePattern);
    end
end
