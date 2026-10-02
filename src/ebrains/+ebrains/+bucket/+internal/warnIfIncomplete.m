function warnIfIncomplete(actions, isCancelled)
% warnIfIncomplete - Warn when files of a sync failed, or when the sync was cancelled
%
%   ebrains.bucket.internal.warnIfIncomplete(actions, isCancelled) raises
%   EBRAINS:Bucket:Sync:Incomplete when a file of the table a sync returns
%   failed, and EBRAINS:Bucket:Sync:Cancelled when isCancelled is true.
%   runSync calls it at the end of a sync, and an
%   ebrains.bucket.SyncJob calls it again in the MATLAB session, because a
%   warning raised on a background worker is not shown.

    arguments
        actions table
        isCancelled (1,1) logical
    end

    isFailed = actions.Status == "failed";
    if any(isFailed)
        failedPaths = actions.Path(isFailed);
        warning('EBRAINS:Bucket:Sync:Incomplete', ...
            ['The sync is incomplete: %d file(s) failed, for example "%s". ' ...
             'The Status and Message variables of the returned table say ' ...
             'which and why. Run the sync again to retry them.'], ...
            numel(failedPaths), failedPaths(1));
    end

    if isCancelled
        warning('EBRAINS:Bucket:Sync:Cancelled', ...
            ['The sync was cancelled: %d file(s) were not copied or deleted. ' ...
             'The Status variable of the returned table says which. Run ' ...
             'the sync again to finish it.'], ...
            sum(ismember(actions.Status, ["cancelled", "skipped"])));
    end
end
