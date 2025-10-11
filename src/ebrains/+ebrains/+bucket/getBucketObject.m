function filePath = getBucketObject(bucketName, objectName, options)
% getBucketObject - Download a object (file) from a dataproxy bucket
%
%   Syntax:
%       S = ebrains.bucket.getBucketObject(bucketName, objectName)
%       downloads a file (object) from the given bucket
%
%   Input Arguments
%       bucketName : Name of the bucket to get object from
%       objectName : Name of the object (file) to download

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        % options.Verbose (1,1) logical = false
        options.TargetFolder (1,1) string {mustBeFolder} = pwd()
    end

    bucket = ebrains.dataproxy.api.Buckets();
    [~, result, ~] = bucket.getDownloadUrl(bucketName, objectName, ...
        'redirect', false); % Redirect is deprecated, need to set it to false

    filePath = fullfile(options.TargetFolder, objectName);
    downloadFile(filePath, result.url)
    if nargout == 0
        clear filePath
    end
end
