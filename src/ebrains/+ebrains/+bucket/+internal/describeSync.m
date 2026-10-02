function description = describeSync(direction, localFolder, bucketName, prefix)
% describeSync - One sentence that says what a sync copies where
%
%   description = ebrains.bucket.internal.describeSync(direction,
%   localFolder, bucketName, prefix) returns text such as
%   'Syncing "data" to bucket "my-bucket", folder "set/".', for direction
%   "ToBucket" or "FromBucket" and a prefix from
%   ebrains.bucket.internal.normalizePrefix.

    arguments
        direction (1,1) string {mustBeMember(direction, ["ToBucket", "FromBucket"])}
        localFolder (1,1) string
        bucketName (1,1) string
        prefix (1,1) string
    end

    remoteLabel = "bucket """ + bucketName + """";
    if prefix ~= ""
        remoteLabel = remoteLabel + ", folder """ + prefix + """";
    end
    if direction == "ToBucket"
        description = sprintf('Syncing "%s" to %s.', localFolder, remoteLabel);
    else
        description = sprintf('Syncing %s to "%s".', remoteLabel, localFolder);
    end
end
