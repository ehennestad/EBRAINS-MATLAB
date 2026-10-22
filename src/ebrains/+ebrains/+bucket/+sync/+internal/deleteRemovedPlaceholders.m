function plan = deleteRemovedPlaceholders(plan, localFiles, listedFiles, manifestFiles, options)
% deleteRemovedPlaceholders - Delete the placeholders of removed objects in a sync from the bucket
%
%   plan = ebrains.bucket.sync.internal.deleteRemovedPlaceholders(plan,
%   localFiles, listedFiles, manifestFiles) sets Action "delete" and Reason
%   "placeholder" for each row of a plan whose local file is the
%   placeholder of an object that the listing the sync made no longer has
%   (see ebrains.bucket.sync.internal.placeholdersOfRemovedObjects). This
%   holds whether or not the sync deletes extraneous files: the folder
%   stands for the bucket, and such a file holds no data. The plan is that
%   of ebrains.bucket.sync.internal.planSync with the listing as source.
%
%   plan = ebrains.bucket.sync.internal.deleteRemovedPlaceholders(...,
%   IgnoreCase=true) matches paths without regard to case.
%
%   See also ebrains.bucket.sync.internal.protectPlaceholders

    arguments
        plan table
        localFiles table
        listedFiles table
        manifestFiles table
        options.IgnoreCase (1,1) logical = false
    end

    removedFiles = ebrains.bucket.sync.internal.placeholdersOfRemovedObjects( ...
        localFiles, listedFiles, manifestFiles, IgnoreCase=options.IgnoreCase);
    isRemoved = ismember(plan.Path, removedFiles.Path);
    plan.Action(isRemoved) = "delete";
    plan.Reason(isRemoved) = "placeholder";
end
