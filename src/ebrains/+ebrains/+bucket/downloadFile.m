function downloadFile(bucketName, objectName, targetFile, options)
% downloadFile - Download an object (file) of an EBRAINS Data Proxy bucket to a given path
%
%   Syntax:
%       ebrains.bucket.downloadFile(bucketName, objectName, targetFile)
%       downloads the object to the local path targetFile, replacing the
%       file if it exists. Unlike getBucketObject, the caller chooses the
%       full path of the file, which is what a virtual bucket needs: its
%       empty placeholder files are already in place and are filled in.
%
%       The object is received in a temporary file next to the target,
%       targetFile + ".part", which replaces the target once the transfer
%       has completed. A failed transfer leaves the target as it was.
%
%       ebrains.bucket.downloadFile(..., Name=Value) sets the options below.
%
%   Input Arguments
%       bucketName : Name of the bucket that holds the object
%       objectName : Name of the object, relative to the bucket root; a
%                    leading "/" is ignored.
%       targetFile : Path of the local file to write. Its folder is
%                    created if it does not exist.
%
%   Name-Value Arguments
%       DisplayMode : Where progress is shown, "Dialog Box" (default) or
%                     "Command Window".
%       Figure      : Parent figure of the progress dialog. By default the
%                     dialog gets a window of its own.
%       Client      : ebrains.bucket.api.BucketsClient that sends the
%                     requests. Meant for tests and custom clients; a
%                     default client is created otherwise.
%
%   See also ebrains.bucket.getBucketObject, ebrains.bucket.createVirtualBucket

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
        objectName (1,1) string {mustBeNonzeroLengthText}
        targetFile (1,1) string {mustBeNonzeroLengthText, mustNotBeFolder}
        options.DisplayMode (1,1) string {mustBeMember(options.DisplayMode, ["Dialog Box", "Command Window"])} = "Dialog Box"
        options.Figure = []
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    objectName = ebrains.bucket.internal.removeLeadingSlash(objectName);

    % The local checks come first, so that an unusable target is reported
    % before a download URL is requested.
    targetFolder = fileparts(targetFile);
    if strlength(targetFolder) > 0 && ~isfolder(targetFolder)
        mkdir(targetFolder)
    end

    downloadUrl = options.Client.getDownloadUrl(bucketName, objectName);

    % The transfer goes to a temporary file that replaces the target only
    % once it has completed, so a failed transfer leaves whatever was at the
    % target (an empty placeholder of a virtual bucket, or an older copy)
    % untouched. The ".part" extension also keeps the file consumer from
    % deriving an extension of its own for a target that has none.
    partFile = targetFile + ".part";
    try
        ebrains.external.filedownload.downloadFile(partFile, downloadUrl, ...
            Filename=objectName, DisplayMode=options.DisplayMode, Figure=options.Figure);
    catch ME
        if isfile(partFile)
            delete(partFile)
        end
        rethrow(ME)
    end
    movefile(partFile, targetFile, "f");
end

function mustNotBeFolder(path)
% mustNotBeFolder - Validate that a path does not name an existing folder
    if isfolder(path)
        error('EBRAINS:Bucket:TargetIsFolder', ...
            'The target "%s" is a folder. Give the path of the file to write.', path)
    end
end
