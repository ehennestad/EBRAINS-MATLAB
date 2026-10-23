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
%       has been assembled. The upload starts over when the size or the
%       modification time of the file, or the part size, differs from
%       the one recorded, or when the Data Proxy no longer knows the
%       recorded upload. Any other error of a resumed upload keeps the
%       manifest, and names it and Resume=false as the ways to start
%       over. When the manifest cannot be written, the upload goes on
%       without it and cannot be resumed, and a warning says so.
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

    % A relative path would be resolved by Java against a folder other
    % than the current folder of MATLAB.
    if isMATLABReleaseOlderThan("R2025a")
        [~, sourceAttributes] = fileattrib(sourceFile); %#ok<FILEATTRIB> filePermissions needs R2025a
        sourceFile = string(sourceAttributes.Name);
    else
        sourceFile = filePermissions(sourceFile).AbsolutePath;
    end

    fileInfo = dir(sourceFile);
    manifest = newManifest(bucketName, objectName, sourceFile, fileInfo.bytes, options.PartSize);
    manifestFile = "";
    if options.Resume
        manifestFile = getManifestFile(options.ResumeFolder, manifest);
        if isfile(manifestFile)
            manifest = readMatchingManifest(manifestFile, manifest);
        end
    end

    if manifest.UploadId == ""
        uploadFromManifest(manifest, manifestFile, options)
    else
        resumeUpload(manifest, manifestFile, options)
    end
end

function resumeUpload(manifest, manifestFile, options)
% resumeUpload - Continue the upload of the manifest, or start over when the Data Proxy no longer knows it
%
%   The API of the Data Proxy states no lifetime for an upload that is
%   not completed, and no answer of its own for an upload id the proxy
%   does not know. A 404 from the part-URL request or the completion of
%   a resumed upload is taken as the only sign that the recorded upload
%   is gone: the manifest is removed and a new upload sends every part.
%   Any other error keeps the manifest, so that the next call resumes
%   again, and names the manifest and Resume=false as the ways to start
%   over instead.

    try
        uploadFromManifest(manifest, manifestFile, options)
    catch exception
        if ~isUnknownUploadError(exception)
            throw(addStartOverHint(exception, manifestFile))
        end
        delete(manifestFile)
        manifest.UploadId = "";
        manifest.PartETags = strings(1, 0);
        uploadFromManifest(manifest, manifestFile, options)
    end
end

function tf = isUnknownUploadError(exception)
% isUnknownUploadError - Whether the Data Proxy answered a request about the upload id with 404
%
%   The identifiers are the ones ebrains.bucket.api.BucketsClient gives
%   a refused part-URL request and a refused completion.

    unknownUploadIds = "EBRAINS:Bucket:" + ["getMultipartUploadUrl", "completeMultipartUpload"] + ":NotFound";
    tf = any(string(exception.identifier) == unknownUploadIds);
end

function exception = addStartOverHint(exception, manifestFile)
% addStartOverHint - Name the manifest of a resumed upload, and Resume=false, in an error
%
%   Returns an MException with the identifier and the causes of the one
%   given, whose message ends with how to start the upload over.

    message = sprintf(['%s\nThe upload was resumed from the manifest "%s". ' ...
        'To start over instead, delete the manifest or pass Resume=false.'], ...
        exception.message, manifestFile);
    hintedException = MException(exception.identifier, "%s", message);
    for i = 1:numel(exception.cause)
        hintedException = hintedException.addCause(exception.cause{i});
    end
    exception = hintedException;
end

function uploadFromManifest(manifest, manifestFile, options)
% uploadFromManifest - Send the parts the manifest lacks and complete the upload
%
%   An upload whose manifest has no id is started first. The manifest
%   file is updated after each accepted part and removed once the object
%   has been assembled; it is "" when progress is not recorded.

    maxAttemptsPerPart = 3;
    fileSizeBytes = manifest.FileSizeBytes;
    numParts = ceil(fileSizeBytes / options.PartSize);

    if manifest.UploadId == ""
        % Written before the upload is started, so that an upload that
        % cannot be resumed is known before the Data Proxy holds parts of it.
        manifestFile = tryWriteManifest(manifestFile, manifest);
        manifest.UploadId = options.Client.initiateMultipartUpload(manifest.BucketName, manifest.ObjectName);
        manifestFile = tryWriteManifest(manifestFile, manifest);
    end

    % One display covers every part. The monitor is deleted on the way
    % out, so an error leaves no dialog open. The parts of a resumed
    % upload count as done before the first request.
    monitor = ebrains.external.webprogress.MultipartProgressMonitor(fileSizeBytes, ...
        DisplayMode=options.DisplayMode, Figure=options.Figure, Filename=manifest.ObjectName);
    monitorCleanup = onCleanup(@() delete(monitor));
    numCompletedParts = numel(manifest.PartETags);
    monitor.addCompletedBytes(min(numCompletedParts*options.PartSize, fileSizeBytes))

    transfer = struct( ...
        "BucketName", manifest.BucketName, ...
        "ObjectName", manifest.ObjectName, ...
        "SourceFile", manifest.SourceFile, ...
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

    options.Client.completeMultipartUpload(manifest.BucketName, manifest.ObjectName, ...
        manifest.UploadId, partETags);

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
        try
            [wasSuccess, response] = transfer.Uploader(transfer.SourceFile, partUrl, ...
                Offset=part.Offset, NumBytes=part.NumBytes, ProgressMonitor=transfer.Monitor);
        catch exception
            throw(ebrains.bucket.internal.redactSignedUrl(exception, partUrl))
        end
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
        "FileModificationTime", getModificationTime(sourceFile), ...
        "PartSize", partSize, ...
        "UploadId", "", ...
        "PartETags", strings(1, 0));
end

function modificationTime = getModificationTime(filePath)
% getModificationTime - Modification time of a file in microseconds since 1970
%
%   The time comes from java.nio, which keeps the fraction of a second
%   that dir rounds away, so that a file written again within the same
%   second is still seen as changed. filePath has to be absolute.

    path = java.io.File(filePath).toPath();
    noLinkOptions = javaArray("java.nio.file.LinkOption", 0);
    fileTime = java.nio.file.Files.getLastModifiedTime(path, noLinkOptions);
    modificationTime = double(fileTime.to(java.util.concurrent.TimeUnit.MICROSECONDS));
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
%   object, the source file, its size and modification time, and the part
%   size are the same, since the parts of another upload, or of another
%   version of the file, cannot complete this one. The times are compared
%   for equality: a file replaced by a copy that keeps an older time has
%   changed as well.

    try
        stored = jsondecode(fileread(manifestFile));
    catch
        % A manifest that is not valid JSON was left by an interrupted
        % write, and the upload starts over.
        return
    end

    requiredFields = ["BucketName", "ObjectName", "SourceFile", "FileSizeBytes", ...
        "FileModificationTime", "PartSize", "UploadId", "PartETags"];
    if ~isstruct(stored) || ~all(isfield(stored, requiredFields))
        return
    end

    isSameUpload = string(stored.BucketName) == manifest.BucketName ...
        && string(stored.ObjectName) == manifest.ObjectName ...
        && string(stored.SourceFile) == manifest.SourceFile ...
        && isequal(stored.FileSizeBytes, manifest.FileSizeBytes) ...
        && isequal(stored.FileModificationTime, manifest.FileModificationTime) ...
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
