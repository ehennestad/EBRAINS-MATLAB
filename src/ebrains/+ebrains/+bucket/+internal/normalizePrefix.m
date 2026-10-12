function prefix = normalizePrefix(prefix)
% normalizePrefix - Name of a folder of a bucket, as a prefix of the names below it
%
%   prefix = ebrains.bucket.internal.normalizePrefix(prefix) returns the
%   folder name without a leading "/" and with a trailing one, so that
%   "results", "/results" and "results/" all give "results/". The names of
%   the objects in the folder start with it. An empty prefix stays empty
%   and stands for the whole bucket.

    arguments
        prefix (1,1) string
    end

    prefix = ebrains.bucket.internal.removeLeadingSlash(prefix);
    if prefix ~= "" && ~endsWith(prefix, "/")
        prefix = prefix + "/";
    end
end
