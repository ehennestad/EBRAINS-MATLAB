function text = readTextFile(filePath)
% readTextFile - Read a UTF-8 text file as a string
%
%   A file that is not UTF-8 text raises EBRAINS:Bucket:NotUTF8Text.
    [fileID, errorMessage] = fopen(filePath, "r");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotReadFile', 'Could not read "%s": %s', filePath, errorMessage)
    end
    closeFile = onCleanup(@() fclose(fileID));
    bytes = reshape(fread(fileID, Inf, "*uint8"), 1, []);
    text = string(native2unicode(bytes, "UTF-8"));
    % native2unicode replaces a byte sequence that is not UTF-8 instead of
    % failing, so a text that does not give the bytes back was not UTF-8.
    % unicode2native gives an empty text as 0x0, so both sides are
    % compared as rows: an empty file is UTF-8 text.
    if ~isequal(reshape(unicode2native(text, "UTF-8"), 1, []), bytes)
        error('EBRAINS:Bucket:NotUTF8Text', ...
            '"%s" is not UTF-8 text. The virtual bucket cannot be used until it is corrected.', filePath)
    end
end
