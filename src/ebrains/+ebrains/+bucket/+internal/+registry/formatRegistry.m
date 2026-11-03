function text = formatRegistry(registry)
% formatRegistry - The text of a registry file, with the buckets and folders sorted by name
%
%   text = ebrains.bucket.internal.registry.formatRegistry(registry)
%   returns the JSON text of virtual-buckets.json for a registry struct
%   (see ebrains.bucket.internal.registry.emptyRegistry): the labels
%   sorted by bucket and the folders by path, in code point order, as
%   spec/README.md#the-registry-file of the ebrains-bucket-sync package
%   says. A root of "" is written as null, and so is a LastOpened of NaT.
%
%   See also ebrains.bucket.internal.registry.parseRegistry

    arguments
        registry (1,1) struct
    end

    labels = sortrows(registry.Labels, "Bucket");
    folders = sortrows(registry.Folders, "Path");

    % jsonencode writes NaN as null, which stands for no root and for a
    % folder recorded without being opened
    data = struct("format_version", 1, "root", NaN);
    if registry.Root ~= ""
        data.root = registry.Root;
    end
    data.buckets = struct("bucket", cellstr(labels.Bucket), "label", cellstr(labels.Label));
    lastOpened = num2cell(nan(height(folders), 1));
    isOpened = ~isnat(folders.LastOpened);
    lastOpened(isOpened) = cellstr(ebrains.bucket.internal.metadata.formatTimes(folders.LastOpened(isOpened)));
    data.folders = struct("path", cellstr(folders.Path), "bucket", cellstr(folders.Bucket), ...
        "prefix", cellstr(folders.Prefix), "pinned", num2cell(folders.Pinned), "last_opened", lastOpened);

    % An empty struct array is written as [], the empty list of the schema
    data.buckets = reshape(data.buckets, [], 1);
    data.folders = reshape(data.folders, [], 1);
    text = string(jsonencode(data, PrettyPrint=true)) + newline;
end
