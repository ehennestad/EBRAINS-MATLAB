function rows = listVirtualBuckets(registry, rootChildren, infoFcn)
% listVirtualBuckets - The rows of the list of virtual buckets, in the order of the spec
%
%   rows = ebrains.bucket.internal.registry.listVirtualBuckets(registry,
%   rootChildren, infoFcn) merges the folders directly below the root
%   (rootChildren, a string column, as
%   ebrains.bucket.internal.registry.rootChildren returns them) with the
%   recorded folders of the registry, as
%   spec/README.md#listing-virtual-buckets of the ebrains-bucket-sync
%   package says. infoFcn(path) gives a struct with the BucketName and
%   Prefix of the bucket.json of a folder, or an empty struct when the
%   folder is not a virtual bucket whose bucket.json can be read
%   (ebrains.bucket.internal.registry.bucketInfoOf reads the file).
%
%   The result is a table with one row per folder and the variables
%       Path       : Absolute path of the folder
%       Bucket     : Name of its bucket, from its bucket.json when that
%                    can be read, else from its entry in the registry
%       Prefix     : Its prefix, from the same source
%       Label      : The label of the bucket, "" for none
%       Pinned     : Whether the folder is pinned
%       LastOpened : When it was last opened, NaT for never
%       Exists     : Whether its bucket.json can be read
%   A folder below the root without a readable bucket.json is left out.
%   Rows are ordered with pinned rows first, then by LastOpened from the
%   latest, rows without a time after those with one, and rows that are
%   equal so far by Path in code point order.
%
%   See also ebrains.bucket.internal.registry.readRegistry

    arguments
        registry (1,1) struct
        rootChildren (:,1) string
        infoFcn (1,1) function_handle
    end

    recorded = registry.Folders;
    candidates = unique([rootChildren; recorded.Path], "stable");
    nRows = numel(candidates);
    bucketNames = strings(nRows, 1);
    prefixes = strings(nRows, 1);
    pinned = false(nRows, 1);
    lastOpened = NaT(nRows, 1, TimeZone="UTC");
    exists = false(nRows, 1);
    isListed = true(nRows, 1);
    for i = 1:nRows
        entryIndex = find(recorded.Path == candidates(i), 1);
        info = infoFcn(candidates(i));
        if ~isempty(info)
            bucketNames(i) = info.BucketName;
            prefixes(i) = info.Prefix;
            exists(i) = true;
        elseif ~isempty(entryIndex)
            bucketNames(i) = recorded.Bucket(entryIndex);
            prefixes(i) = recorded.Prefix(entryIndex);
        else
            isListed(i) = false;
        end
        if ~isempty(entryIndex)
            pinned(i) = recorded.Pinned(entryIndex);
            lastOpened(i) = recorded.LastOpened(entryIndex);
        end
    end

    labels = strings(nRows, 1);
    [hasLabel, labelIndex] = ismember(bucketNames, registry.Labels.Bucket);
    labels(hasLabel) = registry.Labels.Label(labelIndex(hasLabel));

    rows = table(candidates, bucketNames, prefixes, labels, pinned, lastOpened, exists, ...
        'VariableNames', ["Path", "Bucket", "Prefix", "Label", "Pinned", "LastOpened", "Exists"]);
    rows = rows(isListed, :);
    rows = sortrows(rows, ["Pinned", "LastOpened", "Path"], ["descend", "descend", "ascend"], ...
        MissingPlacement="last");
end
