function writeBucketInfo(rootFolder, bucketName, prefix, listedTime)
% writeBucketInfo - Write which bucket a virtual bucket stands for
%
%   ebrains.bucket.internal.metadata.writeBucketInfo(rootFolder,
%   bucketName, prefix, listedTime) writes .ebrains/bucket.json of the
%   folder, creating .ebrains if needed. listedTime is when the manifest
%   was made from a listing, or NaT if it never was. Fields of an existing
%   file that this toolbox does not write are kept, but go through
%   jsondecode and jsonencode, which can change their form: null becomes
%   [], a list of one number becomes the number, and a name that is not a
%   valid MATLAB name, such as "a-b", is renamed.
%
%   See also ebrains.bucket.internal.metadata.readBucketInfo

    arguments
        rootFolder (1,1) string
        bucketName (1,1) string
        prefix (1,1) string
        listedTime (1,1) datetime = NaT
    end

    filePath = fullfile(rootFolder, ebrains.bucket.internal.metadata.folderName(), "bucket.json");
    data = struct();
    if isfile(filePath)
        data = jsondecode(ebrains.bucket.internal.metadata.readTextFile(filePath));
    end

    data.format_version = 1;
    data.bucket = bucketName;
    data.prefix = ebrains.bucket.internal.normalizePrefix(prefix);
    % jsonencode writes NaN as null, which stands for a bucket never listed
    data.listed_at = NaN;
    if ~isnat(listedTime)
        data.listed_at = ebrains.bucket.internal.metadata.formatTimes(listedTime);
    end

    ebrains.bucket.internal.metadata.writeTextFile(filePath, ...
        string(jsonencode(data, PrettyPrint=true)) + newline)
end
