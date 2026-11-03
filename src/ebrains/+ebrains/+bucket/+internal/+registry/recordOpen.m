function registry = recordOpen(registry, folderPath, bucketName, prefix, openedTime)
% recordOpen - Record that a folder was opened as a virtual bucket
%
%   registry = ebrains.bucket.internal.registry.recordOpen(registry,
%   folderPath, bucketName, prefix, openedTime) gives the entry of the
%   folder the bucket and prefix of its bucket.json and the time, and
%   keeps whether it is pinned. A folder without an entry gets one that is
%   not pinned. The path is recorded as given, which the callers make
%   absolute (see ebrains.bucket.internal.absoluteFolderPath); two paths
%   are the same folder when they are equal as text. The time is recorded
%   in UTC to the second, as the file holds it. A bucket that is "" or a
%   prefix that is neither "" nor a folder name with a trailing "/" is
%   an error (EBRAINS:Bucket:InvalidRegistryEntry), since the file could
%   not be read back.
%
%   See also ebrains.bucket.internal.registry.setPinned,
%   ebrains.bucket.internal.registry.removeFolder

    arguments
        registry (1,1) struct
        folderPath (1,1) string
        bucketName (1,1) string
        prefix (1,1) string
        openedTime (1,1) datetime
    end

    ebrains.bucket.internal.registry.assertEntryFields(bucketName, prefix)
    openedTime.TimeZone = "UTC";
    openedTime = dateshift(openedTime, "start", "second");
    folders = registry.Folders;
    isFolder = folders.Path == folderPath;
    if any(isFolder)
        folders.Bucket(isFolder) = bucketName;
        folders.Prefix(isFolder) = prefix;
        folders.LastOpened(isFolder) = openedTime;
    else
        folders = [folders; ebrains.bucket.internal.registry.makeFolderTable( ...
            folderPath, bucketName, prefix, false, openedTime)];
    end
    registry.Folders = folders;
end
