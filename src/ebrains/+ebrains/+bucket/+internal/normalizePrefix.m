function prefix = normalizePrefix(prefix)
% normalizePrefix - Name of a folder of a bucket, as a prefix of the names below it
%
%   prefix = ebrains.bucket.internal.normalizePrefix(prefix) returns the
%   folder name without a leading "/" and with a trailing one, so that
%   "results", "/results" and "results/" all give "results/". The names of
%   the objects in the folder start with it. An empty prefix stays empty
%   and stands for the whole bucket.
%
%   A prefix that is not a plain relative path (see
%   ebrains.bucket.internal.isSafeRelativePath) is an error
%   (EBRAINS:Bucket:InvalidPrefix): the objects of such a folder could not
%   be placed below a local folder, and the prefix could not be recorded
%   in the bucket.json of a virtual bucket, whose schema in the sync
%   contract forbids it. The check is here so that every function that
%   takes a Prefix refuses the same names.

    arguments
        prefix (1,1) string
    end

    givenPrefix = prefix;
    prefix = ebrains.bucket.internal.removeLeadingSlash(prefix);
    if prefix ~= "" && ~endsWith(prefix, "/")
        prefix = prefix + "/";
    end

    % The folder name is checked without its trailing "/", which would
    % count as an empty last segment
    if prefix ~= "" && ~ebrains.bucket.internal.isSafeRelativePath(extractBefore(prefix, strlength(prefix)))
        error('EBRAINS:Bucket:InvalidPrefix', ...
            ['The prefix "%s" does not name a folder of the bucket: a folder name has no empty, "." ' ...
             'or ".." segment, no backslash, and no Windows drive such as "C:" as its first segment. ' ...
             'Give the folder as a name such as "results" or "results/sub".'], givenPrefix)
    end
end
