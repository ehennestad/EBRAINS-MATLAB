function plan = protectPlaceholders(plan, localFiles, manifestFiles)
% protectPlaceholders - Take the placeholders of a virtual bucket out of a sync to the bucket
%
%   plan = ebrains.bucket.sync.internal.protectPlaceholders(plan,
%   localFiles, manifestFiles) sets Action "none" and Reason "placeholder"
%   for each row of a plan whose local file is a placeholder: a file of 0
%   bytes whose manifest entry has more than 0 bytes. Uploading it would
%   replace the object with an empty file, whether the object changed
%   size or was removed since the listing. The plan is that of
%   ebrains.bucket.sync.internal.planSync with the local files as source.
%
%   See also ebrains.bucket.internal.metadata.readManifest

    arguments
        plan table
        localFiles table
        manifestFiles table
    end

    [isLocal, localIndex] = ismember(plan.Path, localFiles.Path);
    [isListed, manifestIndex] = ismember(plan.Path, manifestFiles.Path);

    localBytes = NaN(height(plan), 1);
    localBytes(isLocal) = localFiles.Bytes(localIndex(isLocal));
    manifestBytes = NaN(height(plan), 1);
    manifestBytes(isListed) = manifestFiles.Bytes(manifestIndex(isListed));

    isPlaceholder = localBytes == 0 & manifestBytes > 0;
    plan.Action(isPlaceholder) = "none";
    plan.Reason(isPlaceholder) = "placeholder";
end
