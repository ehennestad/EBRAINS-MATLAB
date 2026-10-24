function tf = isTransferLeftover(paths)
% isTransferLeftover - Find the paths of the files a transfer keeps next to its target
%
%   tf = ebrains.bucket.sync.internal.isTransferLeftover(paths) returns a
%   logical array of the size of paths that is true for every path whose
%   name ends in one of
%       ".sync-part"               - the file a download is received in,
%                                    next to its target, by
%                                    ebrains.bucket.sync.internal.downloadAndReplace
%                                    and by the ebrains-bucket-sync package
%                                    (see ebrains.bucket.sync.internal.downloadPartSuffix)
%       ".multipart_manifest.json" - the manifest the uploader of the
%                                    ebrains-bucket-sync package keeps next
%                                    to a file during a multipart upload
%   Such a file holds no data of its own, and a process killed during the
%   transfer leaves it behind. These paths are therefore left out of both
%   sides of every sync, before any exclude pattern, and of the files the
%   virtual bucket browser shows: the file is never uploaded, downloaded,
%   deleted or shown. The two tools share the names so that each ignores
%   the leftovers of the other in a folder both sync. A file given such a
%   name on purpose is left out as well. The manifest this toolbox keeps
%   during a multipart upload lives under prefdir, outside any synced
%   folder, and needs no entry here.
%
%   Paths are relative to the root of a synced folder, with "/"
%   separators, as ebrains.bucket.internal.metadata.isMetadataPath takes
%   them. The suffixes are matched as written: both tools write them in
%   lowercase.
%
%   See also ebrains.bucket.internal.metadata.isMetadataPath,
%   ebrains.bucket.sync.internal.listLocalFiles, ebrains.bucket.sync.internal.listRemoteFiles

    arguments
        paths string
    end

    suffixes = [ebrains.bucket.sync.internal.downloadPartSuffix(), ".multipart_manifest.json"];
    tf = endsWith(paths, suffixes);
end
