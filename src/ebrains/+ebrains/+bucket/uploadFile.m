function uploadFile(bucketName, objectName, sourceFile, options)
% uploadFile - Upload a file to an EBRAINS Data Proxy bucket
%
%   Syntax:
%       ebrains.bucket.uploadFile(bucketName, objectName, sourceFile)
%       uploads the local file sourceFile to the bucket, where it becomes
%       the object objectName. An existing object of that name is replaced.
%
%       A file larger than MultipartThreshold is sent as a multipart
%       upload: in parts of PartSize bytes, each through a temporary URL
%       of its own, which the Data Proxy assembles into the object once
%       the last part has arrived. The Data Proxy accepts at most 5 GiB
%       in a single request. While Resume is true, the progress of a
%       multipart upload is recorded in a manifest file beside the source
%       file, <sourceFile>.multipart-upload.json, and a later call with
%       the same source file and object sends only the parts that are
%       still missing. The manifest is removed once the object has been
%       assembled.
%
%       ebrains.bucket.uploadFile(..., Name=Value) sets the options below.
%
%   Input Arguments
%       bucketName : Name of the bucket to upload to
%       objectName : Name of the object in the bucket, including any folder
%                    within the bucket, e.g. "data/session1/raw.bin". The
%                    name is relative to the bucket root; a leading "/" is
%                    ignored.
%       sourceFile : Path of the local file to upload
%
%   Name-Value Arguments
%       MultipartThreshold : Size in bytes above which the file is sent
%                            as a multipart upload. Default is 1 GiB.
%       PartSize           : Size in bytes of each part but the last of a
%                            multipart upload. Default is 10 MiB.
%       Resume             : Record the progress of a multipart upload in
%                            the manifest file and resume from it.
%                            Default is true.
%       DisplayMode        : Where progress is shown, "Dialog Box"
%                            (default) or "Command Window".
%       Figure             : Parent figure of the progress dialog. By
%                            default the dialog gets a window of its own.
%       Client             : ebrains.bucket.api.BucketsClient that sends
%                            the requests. Meant for tests and custom
%                            clients; a default client is created
%                            otherwise.
%       Uploader           : Function that performs each transfer, called
%                            as [wasSuccess, response] = Uploader(sourceFile,
%                            url, Name=Value) with the name-value
%                            arguments of ebrains.external.webprogress.upload,
%                            which is the default. A multipart upload
%                            calls it once per part, with Offset, NumBytes
%                            and ProgressMonitor. Meant for tests.
%
%   See also ebrains.bucket.downloadFile, ebrains.bucket.getBucketObject

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        sourceFile (1,1) string {mustBeFile}
        options.MultipartThreshold (1,1) double {mustBePositive} = 2^30
        options.PartSize (1,1) double {mustBeInteger, mustBePositive} = 10*2^20
        options.Resume (1,1) logical = true
        options.DisplayMode (1,1) string ...
            {mustBeMember(options.DisplayMode, ["Dialog Box", "Command Window"])} = "Dialog Box"
        options.Figure = []
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
        options.Uploader (1,1) function_handle = @ebrains.external.webprogress.upload
    end

    objectName = ebrains.bucket.internal.removeLeadingSlash(objectName);

    fileInfo = dir(sourceFile);
    if fileInfo.bytes > options.MultipartThreshold
        ebrains.bucket.internal.uploadFileInParts(bucketName, objectName, sourceFile, ...
            PartSize=options.PartSize, Resume=options.Resume, ...
            DisplayMode=options.DisplayMode, Figure=options.Figure, ...
            Client=options.Client, Uploader=options.Uploader);
    else
        uploadInOneRequest(bucketName, objectName, sourceFile, options);
    end
end

function uploadInOneRequest(bucketName, objectName, sourceFile, options)
% uploadInOneRequest - Send the whole file through one temporary URL

    uploadUrl = options.Client.getUploadUrl(bucketName, objectName);

    [wasSuccess, response] = options.Uploader(...
        sourceFile, uploadUrl, Filename=objectName, ...
        DisplayMode=options.DisplayMode, Figure=options.Figure);

    if ~wasSuccess
        % The uploader's own error has no identifier and drops the response
        % body, which is where the storage backend explains a refusal.
        errorMessage = string(response.StatusLine);
        bodyText = ebrains.common.internal.getResponseBodyText(response);
        if strlength(bodyText) > 0
            errorMessage = errorMessage + ": " + bodyText;
        end
        error('EBRAINS:Bucket:UploadFailed', ...
            'Upload of "%s" to object "%s" of bucket "%s" failed: %s', ...
            sourceFile, objectName, bucketName, errorMessage)
    end
end
