function registry = setPinned(registry, folderPath, pinned, options)
% setPinned - Pin a folder to the top of the list of virtual buckets, or unpin it
%
%   registry = ebrains.bucket.internal.registry.setPinned(registry,
%   folderPath, pinned) sets whether the recorded folder is pinned.
%
%   registry = ebrains.bucket.internal.registry.setPinned(...,
%   Bucket=NAME, Prefix=PREFIX) also records a folder that has no entry,
%   without a time, as a folder of that bucket and prefix. Without them, a
%   folder that is not recorded is an error (EBRAINS:Bucket:NotRecorded).
%
%   See also ebrains.bucket.internal.registry.recordOpen

    arguments
        registry (1,1) struct
        folderPath (1,1) string
        pinned (1,1) logical
        options.Bucket string {mustBeScalarOrEmpty} = string.empty
        options.Prefix string {mustBeScalarOrEmpty} = string.empty
    end

    folders = registry.Folders;
    isFolder = folders.Path == folderPath;
    if ~any(isFolder)
        if isempty(options.Bucket) || isempty(options.Prefix)
            error('EBRAINS:Bucket:NotRecorded', ...
                '"%s" is not recorded. Give its bucket and prefix to pin it.', folderPath)
        end
        folders = [folders; ebrains.bucket.internal.registry.makeFolderTable( ...
            folderPath, options.Bucket, options.Prefix, false, NaT(TimeZone="UTC"))];
        isFolder = folders.Path == folderPath;
    end
    folders.Pinned(isFolder) = pinned;
    registry.Folders = folders;
end
