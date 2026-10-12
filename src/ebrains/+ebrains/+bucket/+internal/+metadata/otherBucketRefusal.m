function message = otherBucketRefusal(info, bucketName, prefix)
% otherBucketRefusal - Why a folder cannot be used for a bucket, or ""
%
%   message = ebrains.bucket.internal.metadata.otherBucketRefusal(info,
%   bucketName, prefix) returns "" when info, as readBucketInfo returns
%   it, is empty or names bucketName and prefix. Otherwise it returns a
%   message that says which bucket the folder is a virtual bucket of: a
%   sync or a listing of another bucket or folder would mix the objects
%   of two buckets in it.

    arguments
        info struct
        bucketName (1,1) string
        prefix (1,1) string
    end

    message = "";
    prefix = ebrains.bucket.internal.normalizePrefix(prefix);
    if isempty(info) || (info.BucketName == bucketName && info.Prefix == prefix)
        return
    end
    message = "The folder is a virtual bucket of " + describe(info.BucketName, info.Prefix) + ...
        ", not of " + describe(bucketName, prefix) + ".";
end

function text = describe(bucketName, prefix)
    text = "bucket """ + bucketName + """";
    if prefix ~= ""
        text = text + ", folder """ + prefix + """";
    end
end
