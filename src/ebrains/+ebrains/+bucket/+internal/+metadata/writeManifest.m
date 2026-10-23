function writeManifest(rootFolder, files)
% writeManifest - Write the objects of a listing as the manifest of a virtual bucket
%
%   ebrains.bucket.internal.metadata.writeManifest(rootFolder, files)
%   writes the file table files, with paths relative to the prefix, to
%   .ebrains/manifest.csv of the folder, creating .ebrains if needed.
%
%   See also ebrains.bucket.internal.metadata.readManifest

    arguments
        rootFolder (1,1) string
        files table
    end

    filePath = fullfile(rootFolder, ebrains.bucket.internal.metadata.folderName(), "manifest.csv");
    ebrains.bucket.internal.metadata.writeTextFile(filePath, ...
        ebrains.bucket.internal.metadata.formatManifest(files))
end
