function info = readBucketInfo(rootFolder)
% readBucketInfo - Read which bucket a virtual bucket stands for
%
%   info = ebrains.bucket.internal.metadata.readBucketInfo(rootFolder)
%   reads .ebrains/bucket.json of the folder and returns a struct with
%   the fields
%       BucketName : Name of the bucket
%       Prefix     : Folder of the bucket, "" for the whole bucket or a
%                    name that ends with "/"
%       ListedTime : When the manifest was last made from a listing, as a
%                    datetime in UTC, or NaT if it never was
%   A folder without the file gives a 0x0 struct with those fields.
%
%   A file of a format version greater than this toolbox knows is an
%   error (EBRAINS:Bucket:UnknownVirtualBucketFormat), since the toolbox
%   cannot tell what it may change in it. So is a file that does not
%   follow virtual-bucket.schema.json of the sync contract
%   (EBRAINS:Bucket:InvalidBucketInfo): one that is not a JSON object in
%   UTF-8, a format_version that is not a whole number from 1, a bucket
%   that is not a nonempty text, a prefix that is neither "" nor a folder
%   name with a trailing "/" that stays below the bucket, or a listed_at
%   that is missing or neither null nor a time written as
%   "2024-01-02T03:04:05Z".
%
%   See also ebrains.bucket.internal.metadata.writeBucketInfo

    arguments
        rootFolder (1,1) string
    end

    info = struct("BucketName", {}, "Prefix", {}, "ListedTime", {});
    filePath = fullfile(rootFolder, ebrains.bucket.internal.metadata.folderName(), "bucket.json");
    if ~isfile(filePath)
        return
    end

    invalid = @(problem) MException('EBRAINS:Bucket:InvalidBucketInfo', ...
        '"%s" cannot be read: %s. The virtual bucket cannot be used until the file is corrected.', ...
        filePath, problem);

    try
        data = jsondecode(ebrains.bucket.internal.metadata.readTextFile(filePath));
    catch exception
        throw(addCause(invalid("it is not JSON text in UTF-8"), exception))
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
        error('EBRAINS:Bucket:UnknownVirtualBucketFormat', ...
            ['"%s" is of a format version this toolbox does not know. ' ...
             'Update the toolbox to use this folder.'], filePath)
    end

    if ~isfield(data, "bucket") || ~isTextScalar(data.bucket) || strlength(string(data.bucket)) == 0
        throw(invalid("bucket is not the name of a bucket"))
    end

    if ~isfield(data, "prefix") || ~isTextScalar(data.prefix) || ~isNormalizedPrefix(string(data.prefix))
        throw(invalid('prefix is neither "" nor a folder name with a trailing "/" that stays below the bucket'))
    end

    if ~isfield(data, "listed_at")
        throw(invalid("it has no listed_at"))
    end
    listedTime = NaT(TimeZone="UTC");
    if ~(isnumeric(data.listed_at) && isempty(data.listed_at)) % JSON null
        listedText = "";
        if isTextScalar(data.listed_at)
            listedText = string(data.listed_at);
        end
        if ~ebrains.bucket.internal.metadata.isTimeText(listedText)
            throw(invalid("listed_at is neither null nor a time in UTC"))
        end
        listedTime = ebrains.bucket.internal.metadata.parseTimes(listedText);
    end

    info(1).BucketName = string(data.bucket);
    info(1).Prefix = string(data.prefix);
    info(1).ListedTime = listedTime;
end

function tf = isTextScalar(value)
% isTextScalar - Whether a decoded JSON value is one text
    tf = (ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value));
end

function tf = isNormalizedPrefix(prefix)
% isNormalizedPrefix - Whether a prefix is "" or a safe folder name with a trailing "/"
    tf = prefix == "" || (endsWith(prefix, "/") ...
        && ebrains.bucket.internal.isSafeRelativePath(extractBefore(prefix, strlength(prefix))));
end
