function info = bucketInfoOf(folderPath)
% bucketInfoOf - The bucket and prefix of the bucket.json of a folder, or empty when it cannot be read
%
%   info = ebrains.bucket.internal.registry.bucketInfoOf(folderPath)
%   returns a struct with BucketName and Prefix, or a 0x0 struct with
%   those fields when the folder has no bucket.json, or has one that is
%   refused (see ebrains.bucket.internal.metadata.readBucketInfo). This
%   is the lookup that the list of virtual buckets is made with.
%
%   See also ebrains.bucket.internal.registry.listVirtualBuckets

    arguments
        folderPath (1,1) string
    end

    info = struct("BucketName", {}, "Prefix", {});
    try
        bucketInfo = ebrains.bucket.internal.metadata.readBucketInfo(folderPath);
    catch
        % A file that cannot be read, or that breaks the schema, makes
        % the folder no virtual bucket for the list
        return
    end
    if ~isempty(bucketInfo)
        info(1).BucketName = bucketInfo.BucketName;
        info(1).Prefix = bucketInfo.Prefix;
    end
end
