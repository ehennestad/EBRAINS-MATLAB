function patterns = readExcludeFile(filePath)
% readExcludeFile - Exclude patterns of an exclude file
%
%   patterns = ebrains.bucket.sync.internal.readExcludeFile(filePath)
%   reads the UTF-8 exclude file at filePath and returns its patterns as a
%   string column vector. ebrains.bucket.sync.internal.parseExcludeFile
%   describes the layout of the file.
%
%   See also ebrains.bucket.sync.internal.parseExcludeFile

    arguments
        filePath (1,1) string {mustBeFile}
    end

    text = string(fileread(filePath, Encoding="UTF-8"));
    try
        patterns = ebrains.bucket.sync.internal.parseExcludeFile(text);
    catch exception
        if exception.identifier ~= "EBRAINS:Bucket:Sync:ExcludeFileNegation"
            rethrow(exception)
        end
        error(exception.identifier, 'Exclude file "%s": %s', filePath, exception.message);
    end
end
