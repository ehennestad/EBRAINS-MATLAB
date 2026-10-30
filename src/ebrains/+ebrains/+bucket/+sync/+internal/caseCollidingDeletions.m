function [isCollision, localPaths] = caseCollidingDeletions(plan, localFiles)
% caseCollidingDeletions - Find the deletions of a sync to the bucket that collide with a local file in case
%
%   [isCollision, localPaths] = ebrains.bucket.sync.internal.caseCollidingDeletions(plan, localFiles)
%   returns, for each row of a plan of ebrains.bucket.sync.internal.planSync
%   with the local files as source, whether the row deletes an object
%   whose name is that of a local file in another case, and the path of
%   that file, "" for the other rows.
%
%   An upload compares names exactly, since the bucket tells names apart,
%   so such an object is extraneous to the plan. On a file system that
%   ignores case the local folder cannot hold the object next to the
%   file: a sync from the bucket keeps only one of the two (see
%   ebrains.bucket.sync.internal.dropCaseCollisions), so the object may be
%   the only copy of its data, and a sync to the bucket must not delete
%   it. Whether the folder ignores case is for the caller to decide (see
%   ebrains.bucket.sync.internal.isCaseInsensitive).
%
%   See also ebrains.bucket.sync.internal.runSync

    arguments
        plan table
        localFiles table
    end

    [isMatched, localIndex] = ismember(lower(plan.Path), lower(localFiles.Path));
    isCollision = plan.Action == "delete" & isMatched;
    localPaths = strings(height(plan), 1);
    localPaths(isCollision) = localFiles.Path(localIndex(isCollision));
end
