function registry = setLabel(registry, bucketName, label)
% setLabel - Give a bucket a label, or remove its label with empty text
%
%   registry = ebrains.bucket.internal.registry.setLabel(registry,
%   bucketName, label) records label as the user's own name for the
%   bucket, kept as given. A label of "" removes the entry of the bucket.
%   A bucket of "" is an error (EBRAINS:Bucket:InvalidRegistryEntry),
%   since the file could not be read back.
%
%   See also ebrains.bucket.internal.registry.recordOpen

    arguments
        registry (1,1) struct
        bucketName (1,1) string
        label (1,1) string
    end

    ebrains.bucket.internal.registry.assertEntryFields(bucketName, "")
    labels = registry.Labels;
    isBucket = labels.Bucket == bucketName;
    if label == ""
        labels(isBucket, :) = [];
    elseif any(isBucket)
        labels.Label(isBucket) = label;
    else
        labels(end+1, :) = {bucketName, label};
    end
    registry.Labels = labels;
end
