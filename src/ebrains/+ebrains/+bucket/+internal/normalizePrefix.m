function prefix = normalizePrefix(prefix)
% normalizePrefix - Folder name in the bucket, without a leading "/" and with a trailing one
%
%   prefix = ebrains.bucket.internal.normalizePrefix(prefix) turns the
%   Prefix option of a sync, such as "/results" or "results/", into the
%   form object names start with, "results/". An empty prefix stays empty.

    arguments
        prefix (1,1) string
    end

    prefix = regexprep(prefix, "^/+", "");
    if prefix ~= "" && ~endsWith(prefix, "/")
        prefix = prefix + "/";
    end
end
