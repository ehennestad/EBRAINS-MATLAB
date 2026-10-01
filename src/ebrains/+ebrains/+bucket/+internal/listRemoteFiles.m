function files = listRemoteFiles(bucketName, prefix, client)
% listRemoteFiles - List the files of a bucket, or of a folder in it, for a sync
%
%   files = ebrains.bucket.internal.listRemoteFiles(bucketName, prefix,
%   client) returns a table with one row per object whose name starts with
%   prefix, with the variables Path, Bytes, ModifiedTime and Hash of
%   ebrains.bucket.internal.makeFileTable. Paths are relative to prefix,
%   which is "" for the whole bucket or a folder name that ends with "/".
%   Objects that mark folders are left out (see
%   ebrains.bucket.internal.isFolderObject).
%
%   ModifiedTime is the time the object was uploaded, which the listing
%   reports, and NaT where it cannot be read. Hash is the MD5 checksum the
%   listing reports, and "" where there is none, or where the value is the
%   checksum of a multipart upload ("<md5>-<parts>"), which does not
%   match the checksum of the file's content.
%
%   See also ebrains.bucket.internal.listLocalFiles, ebrains.bucket.listBucketObjects

    arguments
        bucketName (1,1) string
        prefix (1,1) string
        client (1,1) ebrains.bucket.api.BucketsClient
    end

    objects = ebrains.bucket.listBucketObjects(bucketName, Prefix=prefix, Client=client);

    if isempty(objects)
        files = ebrains.bucket.internal.makeFileTable(strings(0, 1), zeros(0, 1));
        return
    end

    objects = objects(~ebrains.bucket.internal.isFolderObject(objects));
    names = reshape(string({objects.name}), [], 1);

    % The listing is narrowed to the prefix already; the check keeps a
    % name that does not start with it from turning into a wrong path.
    isBelowPrefix = startsWith(names, prefix) & strlength(names) > strlength(prefix);
    objects = objects(isBelowPrefix);
    names = names(isBelowPrefix);

    paths = extractAfter(names, strlength(prefix));
    bytes = zeros(numel(objects), 1);
    for i = 1:numel(objects)
        bytes(i) = double(objects(i).bytes);
    end

    modifiedTimes = parseListingTimes(getTextField(objects, 'last_modified'));

    hashes = getTextField(objects, 'hash');
    hashes(contains(hashes, "-")) = "";

    files = ebrains.bucket.internal.makeFileTable(paths, bytes, modifiedTimes, hashes);
end

function values = getTextField(objects, fieldName)
% getTextField - Text of a field of every object, "" where it is absent or null
    values = strings(numel(objects), 1);
    if ~isfield(objects, fieldName)
        return
    end
    for i = 1:numel(objects)
        value = objects(i).(fieldName);
        if (ischar(value) || isstring(value)) && ~isempty(value)
            values(i) = string(value);
        end
    end
end

function modifiedTimes = parseListingTimes(timeTexts)
% parseListingTimes - Read times such as "2024-05-03T10:22:33.123456" as UTC
%
%   The object store reports times in UTC, with or without a fraction of
%   a second and a "Z" or zero offset. The fraction is dropped, which the
%   tolerance of the time comparison covers. Text in any other form gives
%   NaT, which leaves the time out of the comparison.

    modifiedTimes = NaT(numel(timeTexts), 1);
    modifiedTimes.TimeZone = "UTC";

    timeTexts = regexprep(timeTexts, "(\.\d+)?(Z|[+-]00:?00)?$", "");
    isGiven = timeTexts ~= "";
    inputFormat = "yyyy-MM-dd'T'HH:mm:ss";
    try
        modifiedTimes(isGiven) = datetime(timeTexts(isGiven), ...
            'InputFormat', inputFormat, 'TimeZone', 'UTC');
    catch
        % One text in another form fails the whole conversion, so the
        % times are read one by one to keep the others.
        for i = reshape(find(isGiven), 1, [])
            try
                modifiedTimes(i) = datetime(timeTexts(i), ...
                    'InputFormat', inputFormat, 'TimeZone', 'UTC');
            catch
                % Left as NaT
            end
        end
    end
end
