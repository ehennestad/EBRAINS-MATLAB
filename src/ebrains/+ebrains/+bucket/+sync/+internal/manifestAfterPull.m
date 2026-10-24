function manifestFiles = manifestAfterPull(listedFiles, actions, localFolder, localFiles, oldManifestFiles, options)
% manifestAfterPull - Manifest of a virtual bucket after a sync from the bucket
%
%   manifestFiles = ebrains.bucket.sync.internal.manifestAfterPull(
%   listedFiles, actions, localFolder, localFiles, oldManifestFiles)
%   returns the file table of the listing the sync made, with the entry of
%   each placeholder of a removed object that the sync left in place,
%   sorted by path. actions is the table of ebrains.bucket.sync.fromBucket
%   with the Status of each row, localFiles are the files of the local
%   folder at the sync, and oldManifestFiles the manifest before it.
%
%   A placeholder whose deletion was held back or failed, a row with Reason
%   "placeholder" and a Status other than "done", still stands for its
%   object, so it keeps its entry from oldManifestFiles, as after a sync to
%   the bucket: only the entry tells the next sync to the bucket that the
%   empty file is a placeholder rather than a new file to upload. A file
%   that holds data by now is no placeholder and gets no entry, and nor
%   does a file that is gone.
%
%   manifestFiles = ebrains.bucket.sync.internal.manifestAfterPull(...,
%   IgnoreCase=true) matches paths without regard to case, as the sync
%   does on a file system that ignores the case of names.
%
%   See also ebrains.bucket.sync.internal.manifestAfterPush,
%   ebrains.bucket.sync.internal.deleteRemovedPlaceholders

    arguments
        listedFiles table
        actions table
        localFolder (1,1) string
        localFiles table
        oldManifestFiles table
        options.IgnoreCase (1,1) logical = false
    end

    removedPlaceholders = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects( ...
        localFiles, listedFiles, oldManifestFiles, IgnoreCase=options.IgnoreCase);
    undeletedPaths = actions.Path(actions.Reason == "placeholder" & actions.Status ~= "done");
    isKept = ismember(removedPlaceholders.Path, undeletedPaths);
    for i = reshape(find(isKept), 1, [])
        isKept(i) = isEmptyFile(localFolder, removedPlaceholders.Path(i));
    end
    manifestFiles = sortrows([listedFiles; removedPlaceholders(isKept, :)], "Path");
end

function tf = isEmptyFile(localFolder, relativePath)
% isEmptyFile - Whether the file exists and holds 0 bytes now
    file = ebrains.bucket.sync.internal.listLocalFile(localFolder, relativePath);
    tf = height(file) == 1 && file.Bytes == 0;
end
