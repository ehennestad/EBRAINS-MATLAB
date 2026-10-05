function actions = syncToBucket(localFolder, bucketName, options)
% syncToBucket - Make a Data Proxy bucket match a local folder
%
%   Syntax:
%       ebrains.bucket.syncToBucket(localFolder, bucketName) uploads the
%       files of localFolder and its subfolders that the bucket does not
%       have or that have changed, the way rsync does. Files that are
%       unchanged are not sent again, so running the sync again after an
%       interruption picks up where it stopped. Object names are the paths
%       relative to localFolder, with "/" separators.
%
%       ebrains.bucket.syncToBucket(..., Prefix=FOLDER) syncs to a folder
%       of the bucket instead of its root.
%
%       ebrains.bucket.syncToBucket(..., Delete=true) also deletes the
%       objects that localFolder does not have, which makes the bucket (or
%       the folder of it) an exact mirror of localFolder.
%
%       actions = ebrains.bucket.syncToBucket(...) returns a table with
%       one row per file, and what was done with it.
%
%   Input Arguments
%       localFolder : Folder to upload
%       bucketName  : Name of the bucket to make match it
%
%   Name-Value Arguments
%       Prefix      : Folder of the bucket to sync to, such as "results/".
%                     Default is "", the root of the bucket. Objects
%                     outside the folder are never changed.
%       Delete      : Delete the objects that localFolder does not have.
%                     Default is false, which keeps them.
%       Comparison  : How a file that the bucket has is judged changed:
%                     "SizeAndTime" - (default) the sizes differ, or the
%                                     local file was changed after the
%                                     object was uploaded
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
%       Exclude     : Wildcard patterns of paths to leave out, such as
%                     [".git", "*.tmp", "raw/scratch"]. Excluded files are
%                     neither uploaded nor deleted. See
%                     ebrains.bucket.internal.excludeFiles for the rules.
%       DryRun      : Only plan: list what would be uploaded and deleted,
%                     and change nothing. A deletion that a real run would
%                     refuse (see MaxDelete and below) is listed as skipped
%                     with the reason. Default is false.
%       MaxDelete   : Most objects the sync may delete. If the plan deletes
%                     more, the sync stops before it changes anything.
%                     Default is Inf.
%       Verbose     : Print the plan and the progress. Default is true.
%       DisplayMode : Where the progress of each upload is shown:
%                     "Command Window" (default) or "Dialog Box".
%       Client      : ebrains.bucket.api.BucketsClient that sends the
%                     requests. Meant for tests and custom clients; a
%                     default client is created otherwise.
%       Uploader    : Function that uploads a file to a signed URL, as for
%                     ebrains.bucket.uploadFile. Meant for tests.
%
%   Output Arguments
%       actions : Table with one row per file found on either side, and
%                 the variables
%                 Path    - Path relative to localFolder and Prefix
%                 Action  - "upload", "delete" or "none"
%                 Reason  - "new", "size", "newer", "checksum",
%                           "unchanged", or "extraneous" for an object
%                           localFolder does not have
%                 Bytes   - Size of the file
%                 Status  - "done", "failed", "skipped", "planned" (with
%                           DryRun), or "" for no action
%                 Message - Why an action failed or was skipped
%
%   A file that fails to upload does not stop the sync. The other files
%   are uploaded, nothing is deleted, and a warning names the failure.
%   Run the sync again to retry.
%
%   The sync refuses to delete everything: with Delete=true and an empty
%   localFolder it stops with an error before it changes anything, since
%   that is more often a wrong folder or prefix than what is wanted.
%
%   Folders are not synced as such: an object store holds files, so an
%   empty local folder has nothing to upload.
%
%   Example:
%       % See what would happen, then mirror a results folder to a bucket
%       ebrains.bucket.syncToBucket("results", "my-bucket", ...
%           Prefix="results", Delete=true, DryRun=true);
%       ebrains.bucket.syncToBucket("results", "my-bucket", ...
%           Prefix="results", Delete=true);
%
%   The options other than Client are those of ebrains.bucket.SyncOptions,
%   which holds their defaults and validation.
%
%   See also ebrains.bucket.syncFromBucket, ebrains.bucket.SyncOptions,
%   ebrains.bucket.uploadFile, ebrains.bucket.listBucketObjects

    arguments
        localFolder (1,1) string {mustBeFolder}
        bucketName (1,1) string {mustBeNonzeroLengthText}
        options.?ebrains.bucket.SyncOptions
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    client = options.Client;
    syncOptions = ebrains.bucket.SyncOptions.fromStruct(rmfield(options, "Client"));

    actions = ebrains.bucket.internal.runSync("ToBucket", localFolder, bucketName, syncOptions, client);

    if nargout == 0
        clear actions
    end
end
