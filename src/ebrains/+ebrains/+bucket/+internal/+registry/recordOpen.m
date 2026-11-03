function registry = recordOpen(registry, folderPath, bucketName, prefix, openedTime)
% recordOpen - Record that a folder was opened as a virtual bucket
%
%   registry = ebrains.bucket.internal.registry.recordOpen(registry,
%   folderPath, bucketName, prefix, openedTime) gives the entry of the
%   folder the bucket and prefix of its bucket.json and the time, and
%   keeps whether it is pinned. A folder without an entry gets one that is
%   not pinned. Two paths are the same folder when they are equal as text.
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

    openedTime.TimeZone = "UTC";
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
