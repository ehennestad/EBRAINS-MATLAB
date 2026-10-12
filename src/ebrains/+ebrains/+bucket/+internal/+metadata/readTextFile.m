function text = readTextFile(filePath)
% readTextFile - Read a UTF-8 text file as a string
    [fileID, errorMessage] = fopen(filePath, "r");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotReadFile', 'Could not read "%s": %s', filePath, errorMessage)
    end
    closeFile = onCleanup(@() fclose(fileID));
    bytes = fread(fileID, Inf, "*uint8");
    text = string(native2unicode(reshape(bytes, 1, []), "UTF-8"));
end
