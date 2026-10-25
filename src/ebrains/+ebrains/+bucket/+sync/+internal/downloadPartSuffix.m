function suffix = downloadPartSuffix()
% downloadPartSuffix - Suffix of the temporary file a download is received in
%
%   suffix = ebrains.bucket.sync.internal.downloadPartSuffix() returns
%   ".sync-part". ebrains.bucket.sync.internal.downloadAndReplace receives
%   an object in a file of this suffix next to its target and renames it
%   over the target once the download is complete, and has
%   ebrains.bucket.downloadFile receive the object in a file of the same
%   suffix before that. The ebrains-bucket-sync package receives its
%   downloads under the same suffix, so that each tool recognises the
%   leftovers of the other in a folder both sync (see
%   ebrains.bucket.sync.internal.isTransferLeftover).

    suffix = ".sync-part";
end
