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
%   error, since the toolbox cannot tell what it may change in it.
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

    data = jsondecode(ebrains.bucket.internal.metadata.readTextFile(filePath));
    knownVersion = 1;
    if ~isfield(data, "format_version") || ~isnumeric(data.format_version) ...
            || data.format_version > knownVersion
        error('EBRAINS:Bucket:UnknownVirtualBucketFormat', ...
            ['"%s" is of a format version this toolbox does not know. ' ...
             'Update the toolbox to use this folder.'], filePath)
    end

    listedTime = NaT(TimeZone="UTC");
    if ~isempty(data.listed_at)
        listedTime = ebrains.bucket.internal.metadata.parseTimes(string(data.listed_at));
    end
    info(1).BucketName = string(data.bucket);
    info(1).Prefix = ebrains.bucket.internal.normalizePrefix(string(data.prefix));
    info(1).ListedTime = listedTime;
end
