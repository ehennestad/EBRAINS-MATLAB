function [identifier, reason] = deletionRefusal(plan, nSourceFiles, maxDelete)
% deletionRefusal - Why the planned deletions of a sync look like a mistake, or ""
%
%   [identifier, reason] = ebrains.bucket.sync.internal.deletionRefusal(plan,
%   nSourceFiles, maxDelete) checks the plan of a sync (see
%   ebrains.bucket.sync.internal.planSync) before anything is changed. It
%   returns the identifier of the error a real run stops with and the
%   reason, or two empty strings when the deletions may go ahead:
%       "EBRAINS:Bucket:Sync:EmptySource"      - the source has no files,
%                                                so the sync would empty
%                                                the target
%       "EBRAINS:Bucket:Sync:TooManyDeletions" - the plan deletes more
%                                                than maxDelete files
%   A plan without deletions is never refused. The refusals are those of
%   spec/README.md#refusal of the ebrains-bucket-sync package.
%
%   See also ebrains.bucket.sync.internal.runSync, ebrains.bucket.sync.SyncOptions

    arguments
        plan table
        nSourceFiles (1,1) double
        maxDelete (1,1) double
    end

    identifier = "";
    reason = "";

    isDelete = plan.Action == "delete";
    nDelete = sum(isDelete);
    if nDelete == 0
        return
    end

    % An empty source with Delete would empty the target. That is more
    % often a mistyped folder or prefix than what is wanted, and the
    % target can be emptied with deleteObject or delete instead.
    if nSourceFiles == 0
        identifier = "EBRAINS:Bucket:Sync:EmptySource";
        reason = sprintf(['The source has no files, so the sync would delete ' ...
            'all %d file(s) of the target. Check the folder and the prefix.'], nDelete);
        return
    end

    if nDelete > maxDelete
        identifier = "EBRAINS:Bucket:Sync:TooManyDeletions";
        reason = sprintf(['The sync would delete %d file(s), more than ' ...
            'MaxDelete (%d), for example "%s".'], ...
            nDelete, maxDelete, plan.Path(find(isDelete, 1)));
    end
end
