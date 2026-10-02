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
%       job = ebrains.bucket.syncFromBucket(..., Background=true) runs the
%       sync on a background worker and returns an ebrains.bucket.SyncJob
%       at once, so MATLAB stays free while it runs. wait(job) returns the
%       table. Use DisplayMode="Window" to follow its progress.
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
%                     A local file that was edited after it was downloaded
%                     keeps its edits under "SizeAndTime" if its size is
%                     unchanged. Use "Checksum" to replace it too.
%       Exclude     : Wildcard patterns of paths to leave out, such as
%                     [".git", "*.tmp", "raw/scratch"]. Excluded files are
%                     neither downloaded nor deleted. See
%                     ebrains.bucket.internal.excludeFiles for the rules.
%       DryRun      : Only plan: list what would be downloaded and deleted,
%                     and change nothing. Default is false.
%       MaxDelete   : Most local files the sync may delete. If the plan
%                     deletes more, the sync stops before it changes
%                     anything. Default is Inf.
%       Verbose     : Print the plan and the progress. Default is true.
%       DisplayMode : Where progress is shown:
%                     "Command Window" - (default) the progress of each
%                                        download is printed
%                     "Dialog Box"     - a dialog shows the progress of
%                                        each download
%                     "Window"         - one window shows the progress of
%                                        the whole sync and of each file,
%                                        with a Cancel button
%                     "None"           - nothing is shown
%                     A cancelled sync stops the file in progress and
%                     skips the files not yet downloaded or deleted.
%       Client      : ebrains.bucket.api.BucketsClient that sends the
%                     requests. Meant for tests and custom clients; a
%                     default client is created otherwise.
%       Downloader  : Function that downloads a signed URL to a file, as
%                     for ebrains.bucket.downloadFile. Meant for tests.
%       Background  : Run the sync on a thread-based worker of
%                     backgroundPool and return an ebrains.bucket.SyncJob
%                     instead of the table. Default is false. Only
%                     DisplayMode "Window" shows progress then; the other
%                     modes and Verbose show nothing.
%       ProgressObserver : ebrains.bucket.internal.SyncProgressObserver
%                     that the sync reports its progress to, and asks
%                     whether to cancel. Ignored with DisplayMode
%                     "Window", which makes its own. Meant for tests.
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
%                 Status  - "done", "failed", "cancelled", "skipped",
%                           "planned" (with DryRun), or "" for no action
%                 Message - Why an action failed, was cancelled or was
%                           skipped
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
%   See also ebrains.bucket.syncToBucket, ebrains.bucket.downloadFile,
%   ebrains.bucket.createVirtualBucket

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        localFolder (1,1) string {mustBeNonzeroLengthText}
        options.Prefix (1,1) string = ""
        options.Delete (1,1) logical = false
        options.Comparison (1,1) string ...
            {mustBeMember(options.Comparison, ["SizeAndTime", "Size", "Checksum"])} = "SizeAndTime"
        options.Exclude string = string.empty
        options.DryRun (1,1) logical = false
        options.MaxDelete (1,1) double {mustBeNonnegative} = Inf
        options.Verbose (1,1) logical = true
        options.DisplayMode (1,1) string ...
            {mustBeMember(options.DisplayMode, ["Command Window", "Dialog Box", "Window", "None"])} = "Command Window"
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
        options.Downloader (1,1) function_handle = @ebrains.external.webprogress.download
        options.Background (1,1) logical = false
        options.ProgressObserver (1,1) ebrains.bucket.internal.SyncProgressObserver = ...
            ebrains.bucket.internal.SyncProgressObserver()
    end

    if isfile(localFolder)
        error('EBRAINS:Bucket:Sync:TargetIsFile', ...
            'The target "%s" is a file. Give the path of a folder.', localFolder)
    end

    options.Uploader = @ebrains.external.webprogress.upload;
    if options.Background
        actions = ebrains.bucket.SyncJob("FromBucket", localFolder, bucketName, options);
        return
    end
    actions = ebrains.bucket.internal.runSync("FromBucket", localFolder, bucketName, options);

    if nargout == 0
        clear actions
    end
end
