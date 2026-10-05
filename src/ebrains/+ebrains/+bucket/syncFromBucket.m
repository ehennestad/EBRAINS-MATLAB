function actions = syncFromBucket(bucketName, localFolder, options)
% syncFromBucket - Make a local folder match a Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.syncFromBucket(bucketName, localFolder) downloads
%       the objects of the bucket that localFolder does not have or that
%       have changed, the way rsync does. Files that are unchanged are not
%       downloaded again, so running the sync again after an interruption
%       picks up where it stopped. The folder is created if it does not
%       exist, and the folders of the object names are created below it.
%
%       ebrains.bucket.syncFromBucket(..., Prefix=FOLDER) syncs a folder of
%       the bucket instead of all of it. Paths below localFolder are then
%       relative to that folder.
%
%       ebrains.bucket.syncFromBucket(..., Delete=true) also deletes the
%       local files that the bucket does not have, which makes localFolder
%       an exact mirror of the bucket (or of the folder of it).
%
%       actions = ebrains.bucket.syncFromBucket(...) returns a table with
%       one row per file, and what was done with it.
%
%   Input Arguments
%       bucketName  : Name of the bucket to download
%       localFolder : Folder to make match it
%
%   Name-Value Arguments
%       Prefix      : Folder of the bucket to sync, such as "results/".
%                     Default is "", the whole bucket.
%       Delete      : Delete the local files that the bucket does not
%                     have. Default is false, which keeps them.
%       Comparison  : How a file that localFolder has is judged changed:
%                     "SizeAndTime" - (default) the sizes differ, or the
%                                     object was uploaded after the local
%                                     file was last changed
%                     "Size"        - the sizes differ
%                     "Checksum"    - the sizes or the MD5 checksums
%                                     differ. Reads every local file of
%                                     the same size as its object. Where
%                                     the bucket reports no checksum, the
%                                     file is judged as for "SizeAndTime".
%                                     The checksum of an object uploaded
%                                     in segments is not one of its
%                                     content, so such an object is
%                                     transferred on every sync; objects
%                                     above 5 GB are always segmented and
%                                     are judged by time instead.
%                     A local file that was edited after it was downloaded
%                     keeps its edits under "SizeAndTime" if its size is
%                     unchanged. Use "Checksum" to replace it too.
%       Exclude     : Wildcard patterns of paths to leave out, such as
%                     [".git", "*.tmp", "raw/scratch"]. Excluded files are
%                     neither downloaded nor deleted. See
%                     ebrains.bucket.internal.excludeFiles for the rules.
%       DryRun      : Only plan: list what would be downloaded and deleted,
%                     and change nothing. A deletion that a real run would
%                     refuse (see MaxDelete and below) is listed as skipped
%                     with the reason. Default is false.
%       MaxDelete   : Most local files the sync may delete. If the plan
%                     deletes more, the sync stops before it changes
%                     anything. Default is Inf.
%       Verbose     : Print the plan and the progress. Default is true.
%       DisplayMode : Where the progress of each download is shown:
%                     "Command Window" (default) or "Dialog Box".
%       Client      : ebrains.bucket.api.BucketsClient that sends the
%                     requests. Meant for tests and custom clients; a
%                     default client is created otherwise.
%       Downloader  : Function that downloads a signed URL to a file, as
%                     for ebrains.bucket.downloadFile. Meant for tests.
%
%   Output Arguments
%       actions : Table with one row per file found on either side, and
%                 the variables
%                 Path    - Path relative to localFolder and Prefix
%                 Action  - "download", "delete" or "none"
%                 Reason  - "new", "size", "newer", "checksum",
%                           "unchanged", or "extraneous" for a local file
%                           the bucket does not have
%                 Bytes   - Size of the file
%                 Status  - "done", "failed", "skipped", "planned" (with
%                           DryRun), or "" for no action
%                 Message - Why an action failed or was skipped
%
%   A file that fails to download does not stop the sync. The other files
%   are downloaded, nothing is deleted, and a warning names the failure.
%   Run the sync again to retry. Each download is written to a temporary
%   file first, so a failed download leaves the local file as it was, and
%   the size of each download is checked against the object.
%
%   The sync refuses to delete everything: with Delete=true and an empty
%   bucket or folder of it, it stops with an error before it changes
%   anything, since that is more often a wrong prefix than what is wanted.
%   Folders that become empty when their files are deleted are kept.
%
%   Example:
%       % See what would happen, then mirror a folder of a bucket locally
%       ebrains.bucket.syncFromBucket("my-bucket", "data", ...
%           Prefix="sub-01", Delete=true, DryRun=true);
%       ebrains.bucket.syncFromBucket("my-bucket", "data", ...
%           Prefix="sub-01", Delete=true);
%
%   The options other than Client are those of ebrains.bucket.SyncOptions,
%   which holds their defaults and validation.
%
%   See also ebrains.bucket.syncToBucket, ebrains.bucket.SyncOptions,
%   ebrains.bucket.downloadFile, ebrains.bucket.createVirtualBucket

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        localFolder (1,1) string {mustBeNonzeroLengthText}
        options.?ebrains.bucket.SyncOptions
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    if isfile(localFolder)
        error('EBRAINS:Bucket:Sync:TargetIsFile', ...
            'The target "%s" is a file. Give the path of a folder.', localFolder)
    end

    client = options.Client;
    syncOptions = ebrains.bucket.SyncOptions.fromStruct(rmfield(options, "Client"));

    actions = ebrains.bucket.internal.runSync("FromBucket", localFolder, bucketName, syncOptions, client);

    if nargout == 0
        clear actions
    end
end
