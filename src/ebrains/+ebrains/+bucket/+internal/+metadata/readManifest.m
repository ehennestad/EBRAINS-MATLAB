function [files, isFound] = readManifest(rootFolder)
% readManifest - Read the objects of the last listing of a virtual bucket
%
%   [files, isFound] = ebrains.bucket.internal.metadata.readManifest(rootFolder)
%   reads .ebrains/manifest.csv of the folder and returns its entries as a
%   file table (see ebrains.bucket.sync.internal.makeFileTable), with
%   paths relative to the prefix. A folder that was never listed has no
%   manifest: files is then an empty table and isFound is false.
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
    files = ebrains.bucket.internal.metadata.parseManifest( ...
        ebrains.bucket.internal.metadata.readTextFile(filePath));
end
