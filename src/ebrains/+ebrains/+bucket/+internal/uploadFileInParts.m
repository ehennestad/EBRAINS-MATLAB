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
%       accepted part are recorded in a manifest file in ResumeFolder,
%       one file for each source file, bucket and object. A later call
%       for the same source file and object continues from the first
%       part that is missing, and the manifest is removed once the object
%       has been assembled. The upload starts over when the size of the
%       file, or the part size, differs from the one recorded. When the manifest cannot be written, the upload
%       goes on without it and cannot be resumed, and a warning says so.
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
%       ResumeFolder: Folder of the manifest files. Default is
%                     fullfile(prefdir, "EBRAINS", "multipart-uploads").
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
        options.ResumeFolder (1,1) string = fullfile(prefdir, "EBRAINS", "multipart-uploads")
        options.DisplayMode (1,1) string ...
            {mustBeMember(options.DisplayMode, ["Dialog Box", "Command Window"])} = "Dialog Box"
        options.Figure = []
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
        options.Uploader (1,1) function_handle = @ebrains.external.webprogress.upload
    end

    maxAttemptsPerPart = 3;

    % A relative path would be resolved by Java against a folder other
    % than the current folder of MATLAB.
    [~, sourceAttributes] = fileattrib(sourceFile);
    sourceFile = string(sourceAttributes.Name);

    fileInfo = dir(sourceFile);
    fileSizeBytes = fileInfo.bytes;
    numParts = ceil(fileSizeBytes / options.PartSize);

    manifest = newManifest(bucketName, objectName, sourceFile, fileSizeBytes, options.PartSize);
    manifestFile = "";
    if options.Resume
        manifestFile = getManifestFile(options.ResumeFolder, manifest);
        if isfile(manifestFile)
            manifest = readMatchingManifest(manifestFile, manifest);
        end
    end

    if manifest.UploadId == ""
        % Written before the upload is started, so that an upload that
        % cannot be resumed is known before the Data Proxy holds parts of it.
        manifestFile = tryWriteManifest(manifestFile, manifest);
        manifest.UploadId = options.Client.initiateMultipartUpload(bucketName, objectName);
        manifestFile = tryWriteManifest(manifestFile, manifest);
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
        manifest.PartETags = partETags(1:partNumber);
        manifestFile = tryWriteManifest(manifestFile, manifest);
    end

    options.Client.completeMultipartUpload(bucketName, objectName, manifest.UploadId, partETags);

    if manifestFile ~= "" && isfile(manifestFile)
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

function manifest = newManifest(bucketName, objectName, sourceFile, fileSizeBytes, partSize)
% newManifest - Manifest of an upload that has not started

    manifest = struct( ...
        "BucketName", bucketName, ...
        "ObjectName", objectName, ...
        "SourceFile", sourceFile, ...
        "FileSizeBytes", fileSizeBytes, ...
        "PartSize", partSize, ...
        "UploadId", "", ...
        "PartETags", strings(1, 0));
end

function manifestFile = getManifestFile(resumeFolder, manifest)
% getManifestFile - Path of the manifest of an upload, named after its source file, bucket and object
%
%   The name is the SHA-256 hash of the three, since a path and an object
%   name together can be longer than a file name may be.

    key = jsonencode([manifest.SourceFile, manifest.BucketName, manifest.ObjectName]);
    digest = java.security.MessageDigest.getInstance("SHA-256");
    hashBytes = typecast(digest.digest(unicode2native(key, "UTF-8")), "uint8");
    hashText = lower(string(reshape(dec2hex(hashBytes, 2)', 1, [])));
    manifestFile = fullfile(resumeFolder, hashText + ".json");
end

function manifest = readMatchingManifest(manifestFile, manifest)
% readMatchingManifest - The stored manifest if it is for this upload, else the one given
%
%   The upload id and the ETags are taken over only when the bucket, the
%   object, the source file, its size and the part size are the same,
%   since the parts of another upload cannot complete this one.

    try
        stored = jsondecode(fileread(manifestFile));
    catch
        % A manifest that is not valid JSON was left by an interrupted
        % write, and the upload starts over.
        return
    end

    requiredFields = ["BucketName", "ObjectName", "SourceFile", "FileSizeBytes", ...
        "PartSize", "UploadId", "PartETags"];
    if ~isstruct(stored) || ~all(isfield(stored, requiredFields))
        return
    end

    isSameUpload = string(stored.BucketName) == manifest.BucketName ...
        && string(stored.ObjectName) == manifest.ObjectName ...
        && string(stored.SourceFile) == manifest.SourceFile ...
        && isequal(stored.FileSizeBytes, manifest.FileSizeBytes) ...
        && isequal(stored.PartSize, manifest.PartSize) ...
        && strlength(string(stored.UploadId)) > 0;
    if ~isSameUpload
        return
    end

    manifest.UploadId = string(stored.UploadId);
    manifest.PartETags = reshape(string(stored.PartETags), 1, []);
end

function manifestFile = tryWriteManifest(manifestFile, manifest)
% tryWriteManifest - Record the progress of the upload, or stop recording it if that fails
%
%   Returns "" when the manifest cannot be written, after a warning, so
%   that the upload goes on without one. An empty manifestFile is left
%   as it is.

    if manifestFile == ""
        return
    end

    try
        writeManifest(manifestFile, manifest)
    catch exception
        warning('EBRAINS:Bucket:CannotRecordUploadProgress', ...
            ['Cannot record the progress of the upload of "%s" in "%s": %s. ' ...
            'The upload goes on, but cannot be resumed if it is interrupted.'], ...
            manifest.SourceFile, manifestFile, exception.message)
        manifestFile = "";
    end
end

function writeManifest(manifestFile, manifest)
% writeManifest - Write the manifest file, replacing the one before at once
%
%   The manifest is written to a temporary file in the same folder and
%   then moved over the manifest file, so that an interrupted write
%   leaves the manifest before it in place.

    resumeFolder = fileparts(manifestFile);
    if ~isfolder(resumeFolder)
        [wasCreated, errorMessage] = mkdir(resumeFolder);
        if ~wasCreated
            error('EBRAINS:Bucket:CannotWriteManifest', '%s', errorMessage)
        end
    end

    % The ETags go in as a cell array, so that a single part is written
    % as a JSON array rather than as a string.
    stored = manifest;
    stored.PartETags = cellstr(manifest.PartETags);

    [~, temporaryName] = fileparts(tempname);
    temporaryFile = fullfile(resumeFolder, temporaryName + ".tmp");
    [fileId, errorMessage] = fopen(temporaryFile, "w");
    if fileId < 0
        error('EBRAINS:Bucket:CannotWriteManifest', '%s', errorMessage)
    end
    fprintf(fileId, '%s', jsonencode(stored, PrettyPrint=true));
    fclose(fileId);

    [wasMoved, errorMessage] = movefile(temporaryFile, manifestFile, "f");
    if ~wasMoved
        delete(temporaryFile)
        error('EBRAINS:Bucket:CannotWriteManifest', '%s', errorMessage)
    end
end
