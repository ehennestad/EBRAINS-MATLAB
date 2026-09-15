function name = removeLeadingSlash(name)
% removeLeadingSlash - Remove a leading "/" from the name of a bucket object
%
%   name = ebrains.bucket.internal.removeLeadingSlash(name) returns the
%   name without its leading "/", if it has one. Object names are relative
%   to the bucket root, so a leading "/" would be sent as an empty first
%   folder.

    arguments
        name (1,1) string
    end

    if startsWith(name, "/")
        name = extractAfter(name, 1);
    end
end
