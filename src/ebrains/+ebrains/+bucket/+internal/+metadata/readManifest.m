function [files, isFound] = readManifest(rootFolder)
% readManifest - Read the objects of the last listing of a virtual bucket
%
%   [files, isFound] = ebrains.bucket.internal.metadata.readManifest(rootFolder)
%   reads .ebrains/manifest.csv of the folder and returns its entries as a
%   file table (see ebrains.bucket.sync.internal.makeFileTable), with
%   paths relative to the prefix. A folder that was never listed has no
%   manifest: files is then an empty table and isFound is false.
%
%   A manifest that is not UTF-8 text, or that breaks the layout (see
%   ebrains.bucket.internal.metadata.parseManifest), is an error that
%   names the file and the line.
%
%   See also ebrains.bucket.internal.metadata.writeManifest

    arguments
        rootFolder (1,1) string
    end

    filePath = fullfile(rootFolder, ebrains.bucket.internal.metadata.folderName(), "manifest.csv");
    isFound = isfile(filePath);
    if ~isFound
        files = ebrains.bucket.sync.internal.makeFileTable(strings(0, 1), zeros(0, 1));
        return
    end
    text = ebrains.bucket.internal.metadata.readTextFile(filePath);
    try
        files = ebrains.bucket.internal.metadata.parseManifest(text);
    catch exception
        if exception.identifier ~= "EBRAINS:Bucket:InvalidManifest"
            rethrow(exception)
        end
        error('EBRAINS:Bucket:InvalidManifest', ...
            '"%s", %s The virtual bucket cannot be used until the line is corrected.', ...
            filePath, regexprep(exception.message, '^Line', 'line'))
    end
end
