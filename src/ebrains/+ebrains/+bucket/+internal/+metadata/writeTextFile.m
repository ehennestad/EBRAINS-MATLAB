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
% writeBytes - Write bytes to a file, and fail unless all of them reached it
%
%   The file must be closed before it is moved, and before it is deleted
%   after a failed write, which Windows refuses for an open file. fwrite
%   and fclose report a short write, such as on a full disk, by their
%   return values rather than with an error, and a file that was cut short
%   must not replace the old one.
    [fileID, errorMessage] = fopen(temporaryFile, "w");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotWriteFile', 'Could not write "%s": %s', filePath, errorMessage)
    end
    try
        nWritten = fwrite(fileID, bytes);
    catch exception
        fclose(fileID);
        rethrow(exception)
    end
    closeStatus = fclose(fileID);
    if nWritten ~= numel(bytes)
        error('EBRAINS:Bucket:CouldNotWriteFile', ...
            'Could not write "%s": %d of %d bytes were written.', filePath, nWritten, numel(bytes))
    end
    if closeStatus ~= 0
        error('EBRAINS:Bucket:CouldNotWriteFile', ...
            'Could not write "%s": the file could not be closed.', filePath)
    end
end
