function note = downloadAndReplace(bucketName, objectName, localFile, options)
% downloadAndReplace - Download an object to a temporary file, check it, and put it in place
%
%   note = ebrains.bucket.sync.internal.downloadAndReplace(bucketName,
%   objectName, localFile) downloads the object and replaces the file at
%   localFile with it only once the download is complete, so a failed
%   download leaves the file as it was: the empty placeholder of a virtual
%   bucket, or an older copy. The temporary file sits next to the target,
%   so that the move is a rename on the same file system, and its name
%   ends in ebrains.bucket.sync.internal.downloadPartSuffix, which every
%   sync leaves out, so that a file left behind by a process killed during
%   the download is never uploaded. ebrains.bucket.downloadFile receives
%   the object in a temporary file of its own and renames it over the
%   target at the end. That file gets the same suffix, so a sync leaves
%   it out too. note is "" or says why the file could not be given the
%   time of its object.
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
%       LocalFile     : File table of ebrains.bucket.sync.internal.makeFileTable
%                       with the row of the file at localFile as it was read
%                       when the download was decided, or no rows when there
%                       was no file. Right before the download is put in
%                       place, the file must still have the Bytes and
%                       ModifiedTime of that row, or still be missing;
%                       otherwise the download is discarded with the error
%                       EBRAINS:Bucket:LocalFileChanged, since the file holds
%                       data that was not judged. Default is [], which skips
%                       the check.
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
        options.LocalFile = []
        options.DisplayMode (1,1) string = "Command Window"
        options.Figure = []
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
        options.Downloader (1,1) function_handle = @ebrains.external.webprogress.download
    end

    % movefile puts a file inside a folder of the target name rather than
    % replace it, so an object whose local path is a folder is refused
    % before the download. The empty folder marker of a bucket migrated
    % from the old object storage is listed as a file when no object below
    % it is listed, since only those objects tell it apart from a file.
    if isfolder(localFile)
        error('EBRAINS:Bucket:Sync:LocalPathIsFolder', ...
            ['The object "%s" was not downloaded, since its local path "%s" is a folder. ' ...
             'Rename or remove the folder to download the object.'], ...
            objectName, localFile)
    end

    targetFolder = fileparts(localFile);
    if strlength(targetFolder) > 0 && ~isfolder(targetFolder)
        mkdir(targetFolder)
    end
    temporaryFile = string(tempname(char(targetFolder))) + ebrains.bucket.sync.internal.downloadPartSuffix();
    temporaryFileCleanup = onCleanup(@() deleteIfFile(temporaryFile)); % runs on return or error

    ebrains.bucket.downloadFile(bucketName, objectName, temporaryFile, ...
        TemporarySuffix=ebrains.bucket.sync.internal.downloadPartSuffix(), ...
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

    if istable(options.LocalFile)
        assertLocalFileUnchanged(localFile, options.LocalFile)
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

function assertLocalFileUnchanged(localFile, expected)
% assertLocalFileUnchanged - Error unless the file is as it was when the download was decided
%
%   A file that appeared, vanished, or changed in size or time while the
%   object was downloaded holds data that was not judged, so it is kept.
%   Two unknown times count as the same.
    [folder, name, extension] = fileparts(localFile);
    current = ebrains.bucket.sync.internal.listLocalFile(folder, name + extension);
    isUnchanged = height(current) == height(expected) && (isempty(expected) || ...
        (current.Bytes == expected.Bytes && isequaln(current.ModifiedTime, expected.ModifiedTime)));
    if ~isUnchanged
        error('EBRAINS:Bucket:LocalFileChanged', ...
            ['The file "%s" changed while the object was downloaded, so the download ' ...
             'was discarded. Refresh and try again.'], localFile)
    end
end

function deleteIfFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end
