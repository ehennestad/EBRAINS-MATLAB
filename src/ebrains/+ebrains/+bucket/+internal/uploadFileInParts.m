function uploadFileInParts(bucketName, objectName, sourceFile, options)
% uploadFileInParts - Upload a file to a Data Proxy bucket as a multipart upload
%
%   Syntax:
%       ebrains.bucket.internal.uploadFileInParts(bucketName, objectName, sourceFile)
%       sends the file in parts of PartSize bytes, each through a
%       temporary URL of its own, and asks the Data Proxy to assemble the
%       parts into the object once the last one has been accepted.
%       ebrains.bucket.uploadFile calls this function for a file above
%       its MultipartThreshold.
%
%       While Resume is true, the id of the upload and the ETag of every
%       accepted part are recorded in a manifest file beside the source
%       file, <sourceFile>.multipart-upload.json. A later call with the
%       same source file and object continues from the first part that
%       is missing, and the manifest is removed once the object has been
%       assembled. A manifest for another object, or for a file whose
%       size or part size differs, is not resumed.
%
%       A part that the store refuses is sent again through a new
%       temporary URL, three attempts in all, before the upload is given
%       up. The Data Proxy has no request that abandons a multipart
%       upload, so the parts of an upload that is never completed stay in
%       the store until the service removes them.
%
%   Input Arguments
%       bucketName : Name of the bucket to upload to
%       objectName : Name of the object in the bucket, relative to the
%                    bucket root
%       sourceFile : Path of the local file to upload
%
%   Name-Value Arguments
%       PartSize    : Size in bytes of each part but the last. Default is
%                     10 MiB.
%       Resume      : Record progress in the manifest file and resume
%                     from it. Default is true.
%       DisplayMode : Where progress is shown, "Dialog Box" (default) or
%                     "Command Window".
%       Figure      : Parent figure of the progress dialog. By default the
%                     dialog gets a window of its own.
%       Client      : ebrains.bucket.api.BucketsClient that sends the
%                     requests. Meant for tests and custom clients; a
%                     default client is created otherwise.
%       Uploader    : Function that sends one part, called as
%                     [wasSuccess, response] = Uploader(sourceFile, url,
%                     Offset=offset, NumBytes=numBytes,
%                     ProgressMonitor=monitor) with the name-value
%                     arguments of ebrains.external.webprogress.upload,
%                     which is the default. The response has to carry
%                     the ETag header of the part. Meant for tests.
%
%   See also ebrains.bucket.uploadFile, ebrains.bucket.api.BucketsClient

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        sourceFile (1,1) string {mustBeFile}
        options.PartSize (1,1) double {mustBeInteger, mustBePositive} = 10*2^20
        options.Resume (1,1) logical = true
        options.DisplayMode (1,1) string ...
            {mustBeMember(options.DisplayMode, ["Dialog Box", "Command Window"])} = "Dialog Box"
        options.Figure = []
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
        options.Uploader (1,1) function_handle = @ebrains.external.webprogress.upload
    end

    maxAttemptsPerPart = 3;

    fileInfo = dir(sourceFile);
    fileSizeBytes = fileInfo.bytes;
    numParts = ceil(fileSizeBytes / options.PartSize);
    manifestFile = sourceFile + ".multipart-upload.json";

    manifest = newManifest(bucketName, objectName, fileSizeBytes, options.PartSize);
    if options.Resume && isfile(manifestFile)
        manifest = readMatchingManifest(manifestFile, manifest);
    end

    if manifest.UploadId == ""
        manifest.UploadId = options.Client.initiateMultipartUpload(bucketName, objectName);
        if options.Resume
            writeManifest(manifestFile, manifest)
        end
    end

    % One display covers every part. The monitor is deleted on the way
    % out, so an error leaves no dialog open. The parts of a resumed
    % upload count as done before the first request.
    monitor = ebrains.external.webprogress.MultipartProgressMonitor(fileSizeBytes, ...
        DisplayMode=options.DisplayMode, Figure=options.Figure, Filename=objectName);
    monitorCleanup = onCleanup(@() delete(monitor));
    numCompletedParts = numel(manifest.PartETags);
    monitor.addCompletedBytes(min(numCompletedParts*options.PartSize, fileSizeBytes))

    transfer = struct( ...
        "BucketName", bucketName, ...
        "ObjectName", objectName, ...
        "SourceFile", sourceFile, ...
        "UploadId", manifest.UploadId, ...
        "NumParts", numParts, ...
        "Client", options.Client, ...
        "Uploader", options.Uploader, ...
        "Monitor", monitor);

    partETags = strings(1, numParts);
    partETags(1:numCompletedParts) = manifest.PartETags;

    for partNumber = numCompletedParts+1:numParts
        offset = (partNumber - 1)*options.PartSize;
        part = struct( ...
            "Number", partNumber, ...
            "Offset", offset, ...
            "NumBytes", min(options.PartSize, fileSizeBytes - offset));

        partETags(partNumber) = sendPart(part, transfer, maxAttemptsPerPart);
        if options.Resume
            manifest.PartETags = partETags(1:partNumber);
            writeManifest(manifestFile, manifest)
        end
    end

    options.Client.completeMultipartUpload(bucketName, objectName, manifest.UploadId, partETags);

    if options.Resume && isfile(manifestFile)
        delete(manifestFile)
    end
    close(monitor)
end

function etag = sendPart(part, transfer, maxAttempts)
% sendPart - Send one part until the store accepts it, and return its ETag
%
%   Every attempt asks for a temporary URL of its own, since the URL of
%   a refused attempt may have expired.

    attempt = 0;
    wasSuccess = false;
    while ~wasSuccess && attempt < maxAttempts
        attempt = attempt + 1;
        partUrl = transfer.Client.getMultipartUploadUrl( ...
            transfer.BucketName, transfer.ObjectName, transfer.UploadId, part.Number);
        [wasSuccess, response] = transfer.Uploader(transfer.SourceFile, partUrl, ...
            Offset=part.Offset, NumBytes=part.NumBytes, ProgressMonitor=transfer.Monitor);
    end

    if ~wasSuccess
        % The uploader's own error has no identifier and drops the response
        % body, which is where the storage backend explains a refusal.
        errorMessage = string(response.StatusLine);
        bodyText = ebrains.common.internal.getResponseBodyText(response);
        if strlength(bodyText) > 0
            errorMessage = errorMessage + ": " + bodyText;
        end
        error('EBRAINS:Bucket:UploadFailed', ...
            'Upload of part %d of %d of "%s" to object "%s" of bucket "%s" failed in %d attempts: %s', ...
            part.Number, transfer.NumParts, transfer.SourceFile, transfer.ObjectName, ...
            transfer.BucketName, maxAttempts, errorMessage)
    end

    % The completion request identifies each part by the ETag the store
    % returned for it, so a part without one cannot be assembled.
    etagFields = response.getFields("ETag");
    if isempty(etagFields)
        error('EBRAINS:Bucket:PartETagMissing', ...
            'The store accepted part %d of "%s" but returned no ETag, so the upload cannot be completed.', ...
            part.Number, transfer.SourceFile)
    end
    etag = string(etagFields(1).Value);
end

function manifest = newManifest(bucketName, objectName, fileSizeBytes, partSize)
% newManifest - Manifest of an upload that has not started

    manifest = struct( ...
        "BucketName", bucketName, ...
        "ObjectName", objectName, ...
        "FileSizeBytes", fileSizeBytes, ...
        "PartSize", partSize, ...
        "UploadId", "", ...
        "PartETags", strings(1, 0));
end

function manifest = readMatchingManifest(manifestFile, manifest)
% readMatchingManifest - The stored manifest if it is for this upload, else the one given
%
%   The upload id and the ETags are taken over only when the bucket, the
%   object, the file size and the part size are the same, since the
%   parts of another upload cannot complete this one.

    try
        stored = jsondecode(fileread(manifestFile));
    catch
        % A manifest that is not valid JSON was left by an interrupted
        % write, and the upload starts over.
        return
    end

    requiredFields = ["BucketName", "ObjectName", "FileSizeBytes", "PartSize", "UploadId", "PartETags"];
    if ~isstruct(stored) || ~all(isfield(stored, requiredFields))
        return
    end

    isSameUpload = string(stored.BucketName) == manifest.BucketName ...
        && string(stored.ObjectName) == manifest.ObjectName ...
        && isequal(stored.FileSizeBytes, manifest.FileSizeBytes) ...
        && isequal(stored.PartSize, manifest.PartSize) ...
        && strlength(string(stored.UploadId)) > 0;
    if ~isSameUpload
        return
    end

    manifest.UploadId = string(stored.UploadId);
    manifest.PartETags = reshape(string(stored.PartETags), 1, []);
end

function writeManifest(manifestFile, manifest)
% writeManifest - Record the progress of the upload beside the source file

    % The ETags go in as a cell array, so that a single part is written
    % as a JSON array rather than as a string.
    stored = manifest;
    stored.PartETags = cellstr(manifest.PartETags);

    [fileId, errorMessage] = fopen(manifestFile, "w");
    if fileId < 0
        error('EBRAINS:Bucket:CannotWriteManifest', ...
            'Cannot write the upload manifest "%s": %s. Pass Resume=false to upload without a manifest.', ...
            manifestFile, errorMessage)
    end
    fileCleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId, '%s', jsonencode(stored, PrettyPrint=true));
end
