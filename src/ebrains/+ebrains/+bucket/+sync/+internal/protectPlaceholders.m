function plan = protectPlaceholders(plan, localFiles, listedFiles, manifestFiles)
% protectPlaceholders - Take the placeholders of a virtual bucket out of a sync to the bucket
%
%   plan = ebrains.bucket.sync.internal.protectPlaceholders(plan,
%   localFiles, listedFiles, manifestFiles) sets Action "none" and Reason
%   "placeholder" for each row of a plan whose local file is a
%   placeholder: a file of 0 bytes whose object has more than 0 bytes in
%   the listing the sync made, or had in the manifest of the virtual
%   bucket. Uploading it would replace the object with an empty file, or
%   recreate as an empty object one that was removed since the listing of
%   the manifest. The plan is that of ebrains.bucket.sync.internal.planSync
%   with the local files as source. A virtual bucket that was never listed
%   has an empty manifest, and the listing alone decides.
%
%   See also ebrains.bucket.internal.metadata.readManifest

    arguments
        plan table
        localFiles table
        listedFiles table
        manifestFiles table
    end

    localBytes = bytesOf(plan.Path, localFiles);
    listedBytes = bytesOf(plan.Path, listedFiles);
    manifestBytes = bytesOf(plan.Path, manifestFiles);

    isPlaceholder = localBytes == 0 & (listedBytes > 0 | manifestBytes > 0);
    plan.Action(isPlaceholder) = "none";
    plan.Reason(isPlaceholder) = "placeholder";
end

function bytes = bytesOf(paths, files)
% bytesOf - Size of each path in a file table, NaN where the table lacks it
    [isFound, index] = ismember(paths, files.Path);
    bytes = NaN(numel(paths), 1);
    bytes(isFound) = files.Bytes(index(isFound));
end
