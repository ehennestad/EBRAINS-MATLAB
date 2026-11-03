function recordFolderOpened(folderPath, bucketName, prefix)
% recordFolderOpened - Record in the registry that a folder was opened as a virtual bucket, with the current time
%
%   ebrains.bucket.internal.registry.recordFolderOpened(folderPath,
%   bucketName, prefix) records the absolute path of the existing folder
%   as a folder of the bucket and prefix, opened now (see
%   ebrains.bucket.internal.registry.recordOpen). The registry is a
%   convenience of the user, so a registry that cannot be read or written
%   is reported as a warning (EBRAINS:Bucket:RegistryNotUpdated) and the
%   caller goes on.
%
%   See also ebrains.bucket.createVirtualBucket,
%   ebrains.bucket.app.VirtualBucketBrowser

    arguments
        folderPath (1,1) string
        bucketName (1,1) string
        prefix (1,1) string
    end

    try
        absolutePath = ebrains.bucket.internal.absoluteFolderPath(folderPath);
        ebrains.bucket.internal.registry.updateRegistry(@(registry) ...
            ebrains.bucket.internal.registry.recordOpen(registry, absolutePath, bucketName, prefix, ...
            datetime("now", TimeZone="UTC")));
    catch exception
        warning('EBRAINS:Bucket:RegistryNotUpdated', ...
            'The folder was not recorded in the list of virtual buckets: %s', exception.message)
    end
end
