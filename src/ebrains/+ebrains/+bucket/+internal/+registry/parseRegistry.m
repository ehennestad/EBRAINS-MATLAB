function registry = parseRegistry(text, name)
% parseRegistry - The registry in the text of a registry file
%
%   registry = ebrains.bucket.internal.registry.parseRegistry(text, name)
%   returns the registry struct (see
%   ebrains.bucket.internal.registry.emptyRegistry) that the JSON text of
%   a virtual-buckets.json holds. name is how the file is called in errors.
%
%   A text that does not follow bucket-registry.schema.json of the
%   ebrains-bucket-sync package is an error
%   (EBRAINS:Bucket:InvalidRegistry): one that is not a JSON object, a
%   format_version that is not a whole number from 1, a missing root,
%   buckets or folders, a root that is neither null nor a nonempty text,
%   a bucket or a label that is not a nonempty text, a bucket labelled
%   twice, a folder without a path, with a path recorded twice, with a
%   bucket that is not a nonempty text, a prefix that is neither "" nor a
%   folder name with a trailing "/" that stays below the bucket, a pinned
%   that is not true or false, or a last_opened that is missing or
%   neither null nor a time written as "2024-01-02T03:04:05Z". A
%   format_version greater than this toolbox knows is a separate error
%   (EBRAINS:Bucket:UnknownRegistryFormat). Fields the toolbox does not
%   know are accepted and dropped. jsondecode reads null and an empty
%   list alike, so a root of [], or a buckets, folders or last_opened of
%   null, is taken as none or empty where the ebrains-bucket-sync package
%   refuses it; the toolbox never writes those forms.
%
%   See also ebrains.bucket.internal.registry.formatRegistry

    arguments
        text (1,1) string
        name (1,1) string = "virtual-buckets.json"
    end

    invalid = @(problem) MException('EBRAINS:Bucket:InvalidRegistry', ...
        '"%s" cannot be read: %s. The registry cannot be used until the file is corrected or deleted.', ...
        name, problem);

    try
        data = jsondecode(text);
    catch exception
        throw(addCause(invalid("it is not JSON text"), exception))
    end
    if ~isstruct(data) || ~isscalar(data)
        throw(invalid("it does not hold a JSON object"))
    end

    knownVersion = 1;
    if ~isfield(data, "format_version") || ~isnumeric(data.format_version) ...
            || ~isscalar(data.format_version) || data.format_version < 1 ...
            || data.format_version ~= round(data.format_version)
        throw(invalid("format_version is not a whole number from 1"))
    end
    if data.format_version > knownVersion
        error('EBRAINS:Bucket:UnknownRegistryFormat', ...
            ['"%s" is of a format version this toolbox does not know. ' ...
             'Update the toolbox to use the registry.'], name)
    end
    for key = ["root", "buckets", "folders"]
        if ~isfield(data, key)
            throw(invalid("it has no " + key))
        end
    end

    registry = ebrains.bucket.internal.registry.emptyRegistry();
    if ~isJsonNull(data.root)
        if ~isNonemptyText(data.root)
            throw(invalid("root is neither null nor a path"))
        end
        registry.Root = string(data.root);
    end

    buckets = toObjectList(data.buckets);
    if isempty(buckets) && ~isJsonList(data.buckets)
        throw(invalid("buckets is not a list"))
    end
    labels = registry.Labels;
    for i = 1:numel(buckets)
        item = buckets{i};
        if ~isstruct(item) || ~isscalar(item)
            throw(invalid("an entry of buckets is not an object"))
        end
        if ~isfield(item, "bucket") || ~isNonemptyText(item.bucket)
            throw(invalid("a bucket in buckets is not the name of a bucket"))
        end
        bucket = string(item.bucket);
        if ismember(bucket, labels.Bucket)
            throw(invalid(sprintf('bucket "%s" appears twice in buckets', bucket)))
        end
        if ~isfield(item, "label") || ~isNonemptyText(item.label)
            throw(invalid(sprintf('the label of bucket "%s" is not text of at least one character', bucket)))
        end
        labels(end+1, :) = {bucket, string(item.label)}; %#ok<AGROW>
    end
    registry.Labels = labels;

    folders = toObjectList(data.folders);
    if isempty(folders) && ~isJsonList(data.folders)
        throw(invalid("folders is not a list"))
    end
    paths = strings(numel(folders), 1);
    bucketNames = strings(numel(folders), 1);
    prefixes = strings(numel(folders), 1);
    pinned = false(numel(folders), 1);
    lastOpened = NaT(numel(folders), 1, TimeZone="UTC");
    for i = 1:numel(folders)
        item = folders{i};
        if ~isstruct(item) || ~isscalar(item)
            throw(invalid("an entry of folders is not an object"))
        end
        if ~isfield(item, "path") || ~isNonemptyText(item.path)
            throw(invalid("a path in folders is not a path"))
        end
        paths(i) = string(item.path);
        if ismember(paths(i), paths(1:i-1))
            throw(invalid(sprintf('path "%s" appears twice in folders', paths(i))))
        end
        if ~isfield(item, "bucket") || ~isNonemptyText(item.bucket)
            throw(invalid(sprintf('the bucket of folder "%s" is not the name of a bucket', paths(i))))
        end
        bucketNames(i) = string(item.bucket);
        if ~isfield(item, "prefix") || ~isText(item.prefix) || ~isNormalizedPrefix(string(item.prefix))
            throw(invalid(sprintf(['the prefix of folder "%s" is neither "" nor a folder name ' ...
                'with a trailing "/" that stays below the bucket'], paths(i))))
        end
        prefixes(i) = string(item.prefix);
        if ~isfield(item, "pinned") || ~islogical(item.pinned) || ~isscalar(item.pinned)
            throw(invalid(sprintf('the pinned of folder "%s" is not true or false', paths(i))))
        end
        pinned(i) = item.pinned;
        if ~isfield(item, "last_opened")
            throw(invalid(sprintf('folder "%s" has no last_opened', paths(i))))
        end
        if ~isJsonNull(item.last_opened)
            openedText = "";
            if isText(item.last_opened)
                openedText = string(item.last_opened);
            end
            if ~ebrains.bucket.internal.metadata.isTimeText(openedText)
                throw(invalid(sprintf('the last_opened of folder "%s" is neither null nor a time in UTC', paths(i))))
            end
            lastOpened(i) = ebrains.bucket.internal.metadata.parseTimes(openedText);
        end
    end
    registry.Folders = ebrains.bucket.internal.registry.makeFolderTable( ...
        paths, bucketNames, prefixes, pinned, lastOpened);
end

function tf = isJsonNull(value)
% isJsonNull - Whether a decoded JSON value was null (or an empty list, which jsondecode reads the same)
    tf = isnumeric(value) && isempty(value);
end

function tf = isJsonList(value)
% isJsonList - Whether a decoded JSON value can have been a list
%
%   jsondecode reads a list of objects as a struct array or a cell array,
%   an empty list as [], and a list of numbers as a numeric array.
    tf = isstruct(value) || iscell(value) || (isnumeric(value) && isempty(value));
end

function items = toObjectList(value)
% toObjectList - The objects of a decoded JSON list as a cell array of scalar structs
%
%   jsondecode gives a struct array for objects that all have the same
%   fields, a cell array otherwise, and [] for an empty list. A value
%   that is no list gives a cell with that value, so that the caller
%   refuses it as an entry that is not an object.
    if isstruct(value)
        items = reshape(num2cell(value), [], 1);
    elseif iscell(value)
        items = reshape(value, [], 1);
    elseif isempty(value)
        items = {};
    else
        items = {value};
    end
end

function tf = isText(value)
% isText - Whether a decoded JSON value is one text
    tf = (ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value));
end

function tf = isNonemptyText(value)
    tf = isText(value) && strlength(string(value)) > 0;
end

function tf = isNormalizedPrefix(prefix)
% isNormalizedPrefix - Whether a prefix is "" or a safe folder name with a trailing "/"
    tf = prefix == "" || (endsWith(prefix, "/") ...
        && ebrains.bucket.internal.isSafeRelativePath(extractBefore(prefix, strlength(prefix))));
end
