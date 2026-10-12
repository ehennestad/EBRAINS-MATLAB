function note = downloadAndReplace(bucketName, objectName, localFile, options)
% downloadAndReplace - Download an object to a temporary file, check it, and put it in place
%
%   note = ebrains.bucket.sync.internal.downloadAndReplace(bucketName,
%   objectName, localFile) downloads the object and replaces the file at
%   localFile with it only once the download is complete, so a failed
%   download leaves the file as it was: the empty placeholder of a virtual
%   bucket, or an older copy. The temporary file sits next to the target,
%   so that the move is a rename on the same file system. note is "" or
%   says why the file could not be given the time of its object.
%
%   Name-Value Arguments
%       ExpectedBytes : Size the listing reports for the object. A download
%                       of another size is an error, since the object was
%                       replaced between the listing and the download.
%                       Default is NaN, which skips the check.
%       ModifiedTime  : Time of the object, which the file is given once in
%                       place. A file with the time of its object is
%                       unchanged to the time comparison of a later sync in
%                       either direction; with the time of its download it
%                       would be newer than its object, and
%                       ebrains.bucket.sync.toBucket would upload it again.
%                       Default is NaT, which keeps the time of the
%                       download.
%       DisplayMode   : Where progress is shown, as for ebrains.bucket.downloadFile.
%       Figure        : Parent figure of the progress dialog.
%       Client        : ebrains.bucket.api.BucketsClient that sends the requests.
%       Downloader    : Function that performs the transfer, as for
%                       ebrains.bucket.downloadFile. Meant for tests.
%
%   See also ebrains.bucket.downloadFile, ebrains.bucket.sync.fromBucket

    arguments
        bucketName (1,1) string
        objectName (1,1) string
        localFile (1,1) string
        options.ExpectedBytes (1,1) double = NaN
        options.ModifiedTime (1,1) datetime = NaT
        options.DisplayMode (1,1) string = "Command Window"
        options.Figure = []
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
        options.Downloader (1,1) function_handle = @ebrains.external.webprogress.download
    end

    targetFolder = fileparts(localFile);
    if strlength(targetFolder) > 0 && ~isfolder(targetFolder)
        mkdir(targetFolder)
    end
    temporaryFile = string(tempname(char(targetFolder))) + ".sync-part";
    temporaryFileCleanup = onCleanup(@() deleteIfFile(temporaryFile)); % runs on return or error

    ebrains.bucket.downloadFile(bucketName, objectName, temporaryFile, ...
        DisplayMode=options.DisplayMode, Figure=options.Figure, ...
        Client=options.Client, Downloader=options.Downloader);

    fileInfo = dir(temporaryFile);
    if isempty(fileInfo)
        error('EBRAINS:Bucket:Sync:DownloadMissing', ...
            'The download of "%s" produced no file.', objectName)
    end
    if ~isnan(options.ExpectedBytes) && fileInfo(1).bytes ~= options.ExpectedBytes
        error('EBRAINS:Bucket:Sync:SizeMismatch', ...
            'The downloaded file "%s" has %d bytes, where the object has %d.', ...
            objectName, fileInfo(1).bytes, options.ExpectedBytes)
    end

    movefile(temporaryFile, localFile, "f")

    note = setModifiedTime(localFile, options.ModifiedTime);
end

function note = setModifiedTime(filePath, modifiedTime)
% setModifiedTime - Give a downloaded file the modification time of its object
%
%   MATLAB has no function that sets the time of a file, so Java does it.
%   Without Java, or without a known time, the file keeps the time of its
%   download. note is "" or says why the time could not be set.

    note = "";
    if isnat(modifiedTime) || ~usejava('jvm')
        return
    end

    % Java resolves a relative path against its own working directory,
    % which need not be MATLAB's, so the path is made absolute.
    fileInfo = dir(filePath);
    absolutePath = fullfile(fileInfo(1).folder, fileInfo(1).name);
    epochMilliseconds = round(posixtime(modifiedTime) * 1000);
    if ~java.io.File(char(absolutePath)).setLastModified(epochMilliseconds)
        note = "Downloaded, but the file kept the time of the download, " + ...
            "so a sync to the bucket would upload it again.";
    end
end

function deleteIfFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end
