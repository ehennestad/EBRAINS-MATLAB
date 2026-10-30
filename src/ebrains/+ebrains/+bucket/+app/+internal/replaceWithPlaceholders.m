function replaceWithPlaceholders(rootFolder, files)
% replaceWithPlaceholders - Empty downloaded files so that they are online only
%
%   ebrains.bucket.app.internal.replaceWithPlaceholders(rootFolder, files)
%   replaces each file of the file table files (see
%   ebrains.bucket.sync.internal.makeFileTable), given by its Path relative
%   to rootFolder with "/" separators, with an empty placeholder file of
%   the same name. The data of the files is discarded.
%
%   The rows of files are the files as they were read when the decision
%   to discard their data was made. A file is emptied only while it still
%   has the Bytes and ModifiedTime of its row: a file that is missing or
%   has changed since holds data that was not judged. A file that is a
%   symbolic link points to data outside rootFolder. Each of these is an
%   error, reported before any file is changed. An unknown time in the
%   row matches an unknown time at the check. Before R2024b links are
%   found with Java, which needs an absolute rootFolder, and without Java
%   no link is found.
%
%   See also ebrains.bucket.app.internal.createPlaceholderFiles, ebrains.bucket.sync.internal.listLocalFile

    arguments
        rootFolder (1,1) string
        files table
    end

    for i = 1:height(files)
        filePath = fullfile(rootFolder, files.Path(i));
        % Opening a link for writing would empty the file it points to,
        % which is not the virtual bucket's to discard
        if ebrains.bucket.sync.internal.isSymbolicLink(filePath)
            error('EBRAINS:Bucket:FileIsLink', ...
                ['"%s" is a symbolic link to a file elsewhere, which cannot be made online only, ' ...
                 'so no file was. Remove the link to make the object online only.'], filePath)
        end
        current = ebrains.bucket.sync.internal.listLocalFile(rootFolder, files.Path(i));
        if isempty(current)
            error('EBRAINS:Bucket:FileNotFound', ...
                'The file "%s" does not exist, so no file was made online only.', filePath)
        end
        % isequaln takes two unknown times as the same: a file whose time
        % cannot be read has none at the decision and at this check alike.
        if current.Bytes ~= files.Bytes(i) || ~isequaln(current.ModifiedTime, files.ModifiedTime(i))
            error('EBRAINS:Bucket:LocalFileChanged', ...
                ['The file "%s" changed since it was read, so no file was made online only. ' ...
                 'Refresh and try again.'], filePath)
        end
    end

    for filePath = reshape(fullfile(rootFolder, files.Path), 1, [])
        % Opening a file for writing empties it and keeps its name, which
        % is all a placeholder of a virtual bucket is.
        [fileID, errorMessage] = fopen(filePath, "w");
        if fileID == -1
            error('EBRAINS:Bucket:CouldNotCreateVirtualFile', ...
                'Failed to empty the file "%s": %s', filePath, errorMessage)
        end
        fclose(fileID);
    end
end
