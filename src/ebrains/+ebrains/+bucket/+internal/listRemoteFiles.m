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
%   Objects whose names could not be used as paths below a folder (a ".."
%   segment, say) are left out with a warning; see
%   ebrains.bucket.internal.isSafeRelativePath.
%
%   ModifiedTime is the time the object was uploaded, which the listing
%   reports, and NaT where it cannot be read. Hash is the MD5 checksum the
%   listing reports, and "" where there is none or where it cannot be the
%   checksum of the content: the value of a multipart upload
%   ("<md5>-<parts>"), or that of an object above 5 GiB, which the object
%   store holds as segments behind a manifest whose checksum is one of the
%   segment checksums. A smaller object uploaded in segments reports such
%   a checksum too, and cannot be told apart in the listing.
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

    isSafe = ebrains.bucket.internal.isSafeRelativePath(paths);
    if ~all(isSafe)
        warning('EBRAINS:Bucket:UnsafeObjectName', ...
            ['%d object(s) of bucket "%s" have names that do not stay below ' ...
             'the synced folder, for example "%s", and are left out of the sync.'], ...
            sum(~isSafe), bucketName, names(find(~isSafe, 1)));
        objects = objects(isSafe);
        paths = paths(isSafe);
    end

    bytes = zeros(numel(objects), 1);
    for i = 1:numel(objects)
        bytes(i) = double(objects(i).bytes);
    end

    modifiedTimes = parseListingTimes(getTextField(objects, 'last_modified'));

    hashes = getTextField(objects, 'hash');
    maxSingleObjectBytes = 5 * 1024^3;
    hashes(contains(hashes, "-") | bytes > maxSingleObjectBytes) = "";

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
%   The object store reports times in UTC without a zone, with or without
%   a fraction of a second. A "Z" or an offset such as "+02:00" is read
%   too, in case a listing carries one. The fraction is dropped, which the
%   tolerance of the time comparison covers. Text in any other form gives
%   NaT, which leaves the time out of the comparison.

    modifiedTimes = NaT(numel(timeTexts), 1);
    modifiedTimes.TimeZone = "UTC";

    timeTexts = regexprep(timeTexts, "\.\d+", "");
    timeTexts = regexprep(timeTexts, "Z$", "+00:00");
    timeTexts = regexprep(timeTexts, "([+-]\d{2})(\d{2})$", "$1:$2");

    hasOffset = endsWith(timeTexts, regexpPattern("[+-]\d{2}:\d{2}"));
    isGiven = timeTexts ~= "";

    modifiedTimes(isGiven & hasOffset) = readTimes( ...
        timeTexts(isGiven & hasOffset), "yyyy-MM-dd'T'HH:mm:ssXXX");
    modifiedTimes(isGiven & ~hasOffset) = readTimes( ...
        timeTexts(isGiven & ~hasOffset), "yyyy-MM-dd'T'HH:mm:ss");
end

function times = readTimes(texts, inputFormat)
% readTimes - datetime of each text in UTC, NaT where it is not in the format
    try
        times = datetime(texts, 'InputFormat', inputFormat, 'TimeZone', 'UTC');
    catch
        % One text in another form fails the whole conversion, so the
        % times are read one by one to keep the others.
        times = NaT(numel(texts), 1);
        times.TimeZone = "UTC";
        for i = 1:numel(texts)
            try
                times(i) = datetime(texts(i), 'InputFormat', inputFormat, 'TimeZone', 'UTC');
            catch
                % Left as NaT
            end
        end
    end
end
