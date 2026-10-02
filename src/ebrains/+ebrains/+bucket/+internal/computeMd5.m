function hash = computeMd5(filePath)
% computeMd5 - MD5 checksum of a file, as lowercase hexadecimal text
%
%   hash = ebrains.bucket.internal.computeMd5(filePath) reads the file in
%   blocks, so files larger than memory can be checked, and returns the
%   checksum in the form the object store reports it.

    arguments
        filePath (1,1) string {mustBeFile}
    end

    [fileID, errorMessage] = fopen(filePath, "r");
    if fileID == -1
        error('EBRAINS:Bucket:CouldNotReadFile', ...
            'Could not open "%s" to compute its checksum: %s', filePath, errorMessage)
    end
    closeFile = onCleanup(@() fclose(fileID));

    digest = java.security.MessageDigest.getInstance('MD5');
    blockSize = 16 * 1024^2;
    while true
        block = fread(fileID, blockSize, '*uint8');
        if isempty(block)
            break
        end
        digest.update(typecast(block, 'int8'));
    end

    hashBytes = typecast(digest.digest(), 'uint8');
    hash = lower(string(reshape(dec2hex(hashBytes, 2).', 1, [])));
end
