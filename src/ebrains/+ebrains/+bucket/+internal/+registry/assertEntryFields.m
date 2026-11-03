function assertEntryFields(bucketName, prefix)
% assertEntryFields - Refuse a bucket or prefix that the registry file could not hold
%
%   ebrains.bucket.internal.registry.assertEntryFields(bucketName, prefix)
%   raises EBRAINS:Bucket:InvalidRegistryEntry for a bucket that is ""
%   or a prefix that is neither "" nor a folder name with a trailing "/"
%   that stays below the bucket (see ebrains.bucket.internal.isSafeRelativePath).
%   A file with such an entry would be refused when read back.
%
%   See also ebrains.bucket.internal.registry.recordOpen

    arguments
        bucketName (1,1) string
        prefix (1,1) string
    end

    if bucketName == ""
        error('EBRAINS:Bucket:InvalidRegistryEntry', 'The bucket is not the name of a bucket.')
    end
    isNormalized = prefix == "" || (endsWith(prefix, "/") ...
        && ebrains.bucket.internal.isSafeRelativePath(extractBefore(prefix, strlength(prefix))));
    if ~isNormalized
        error('EBRAINS:Bucket:InvalidRegistryEntry', ...
            'The prefix "%s" is neither "" nor a folder name with a trailing "/" that stays below the bucket.', prefix)
    end
end
