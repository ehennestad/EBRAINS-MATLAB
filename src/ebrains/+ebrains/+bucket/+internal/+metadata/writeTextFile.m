function writeTextFile(filePath, text)
% writeTextFile - Write a string to a UTF-8 file so that an interrupted write leaves the old file
%
%   ebrains.bucket.internal.metadata.writeTextFile(filePath, text) writes
%   the text in full to a temporary file in the folder of filePath, and
%   then moves it over filePath. The folder is created if needed.

    arguments
        filePath (1,1) string
        text (1,1) string
    end

    folder = fileparts(filePath);
    if ~isfolder(folder)
        mkdir(folder)
    end

    temporaryFile = string(tempname(folder)) + ".tmp";
    try
        writeBytes(temporaryFile, unicode2native(char(text), "UTF-8"), filePath)
        movefile(temporaryFile, filePath, "f");
    catch exception
        if isfile(temporaryFile)
            delete(temporaryFile)
        end
        rethrow(exception)
    end
end

function writeBytes(temporaryFile, bytes, filePath)
% writeBytes - Write bytes to a file that is closed again whether the write succeeds or fails
%
%   The file must be closed before it is moved, and before it is deleted
%   after a failed write, which Windows refuses for an open file.
    [fileID, errorMessage] = fopen(temporaryFile, "w");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotWriteFile', 'Could not write "%s": %s', filePath, errorMessage)
    end
    closeFile = onCleanup(@() fclose(fileID));
    fwrite(fileID, bytes);
end
