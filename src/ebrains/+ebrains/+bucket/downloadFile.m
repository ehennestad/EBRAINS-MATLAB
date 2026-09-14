function downloadFile(bucketName, objectName, targetFile, options)
% downloadFile - Download an object (file) of an EBRAINS Data Proxy bucket to a given path
%
%   Syntax:
%       ebrains.bucket.downloadFile(bucketName, objectName, targetFile)
%       downloads the object to the local path targetFile, replacing the
%       file if it exists. Unlike getBucketObject, the caller chooses the
%       full path of the file. This is what a virtual bucket needs: its
%       empty placeholder files are already in place and are filled in.
%
%       ebrains.bucket.downloadFile(..., Client=client) sends the requests
%       through the given client instead of a default one.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Name of the object, relative to the bucket root; a
%                    leading "/" is ignored.
%       targetFile : Path of the local file to write. Its folder is
%                    created if it does not exist.
%
%   Name-Value Arguments
%       Client : ebrains.bucket.api.BucketsClient that sends the requests.
%                Meant for tests and custom clients; a default client is
%                created otherwise.
%
%   See also ebrains.bucket.getBucketObject, ebrains.bucket.createVirtualBucket

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        targetFile (1,1) string
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    % Names are relative to the bucket root, so a leading "/" would be
    % sent as an empty first folder.
    objectName = removeLeadingSlash(objectName);

    % The expected size lets the cleanup below tell a partial download from
    % one that completed before the error was raised.
    expectedSizeBytes = ebrains.bucket.getFileSize(bucketName, objectName, Client=options.Client);
    downloadUrl = options.Client.getDownloadUrl(bucketName, objectName);

    targetFolder = fileparts(targetFile);
    if strlength(targetFolder) > 0 && ~isfolder(targetFolder)
        mkdir(targetFolder)
    end

    % Only a file that was there before the transfer, i.e. the placeholder
    % of a virtual bucket, is put back if the transfer fails.
    hadPlaceholder = isfile(targetFile);

    try
        ebrains.external.filedownload.downloadFile(targetFile, downloadUrl, ...
            ShowFilename=true, FileSizeBytes=expectedSizeBytes);
    catch ME
        % A failed transfer can leave a partial file behind. Remove it, and
        % put back an empty placeholder where one was, so a virtual bucket
        % keeps its file listing.
        if isfile(targetFile) && getLocalFileSize(targetFile) ~= expectedSizeBytes
            delete(targetFile)
            if hadPlaceholder
                createEmptyFile(targetFile)
            end
        end
        rethrow(ME)
    end
end

function name = removeLeadingSlash(name)
    if startsWith(name, "/")
        name = extractAfter(name, 1);
    end
end

function fileSizeBytes = getLocalFileSize(filePath)
    fileInfo = dir(filePath);
    fileSizeBytes = fileInfo.bytes;
end

function createEmptyFile(filePath)
% createEmptyFile - Create an empty placeholder file
%
%   Uses fopen rather than a shell command so paths with spaces or shell
%   metacharacters need no quoting and the function also works on Windows.

    [fileID, errorMessage] = fopen(filePath, "w");
    if fileID == -1
        % Warn rather than error: the caller is about to rethrow the download
        % error, which is the one the user needs to see.
        warning('EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
            'Failed to recreate the placeholder file %s:\n%s', filePath, errorMessage)
        return
    end
    fclose(fileID);
end
