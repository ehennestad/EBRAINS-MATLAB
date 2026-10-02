function hash = computeMd5(filePath)
% computeMd5 - MD5 checksum of a file, as lowercase hexadecimal text
%
%   hash = ebrains.bucket.internal.computeMd5(filePath) returns the
%   checksum in the form the object store reports it. The MD5 tool of the
%   operating system computes it: md5 on macOS, md5sum on Linux and
%   certutil on Windows. MATLAB has no MD5 function of its own, and Java,
%   which has one, is not available on the thread-based worker that runs
%   a background sync.

    arguments
        filePath (1,1) string {mustBeFile}
    end

    % certutil fails on an empty file (error 0x800703ee) instead of
    % hashing it, so the checksum of no data is given directly.
    md5OfNoData = "d41d8cd98f00b204e9800998ecf8427e";
    if dir(filePath).bytes == 0
        hash = md5OfNoData;
        return
    end

    if ismac
        command = "md5 -q " + quoteForPosixShell(filePath);
    elseif isunix
        command = "md5sum " + quoteForPosixShell(filePath);
    else
        % A Windows path cannot hold a double quote, so quoting it in
        % double quotes is enough.
        command = "certutil -hashfile """ + filePath + """ MD5";
    end

    [status, output] = system(command);
    if status ~= 0
        error('EBRAINS:Bucket:CouldNotReadFile', ...
            'Could not compute the checksum of "%s": %s', filePath, strtrim(output))
    end
    hash = parseToolOutput(string(output));
end

function hash = parseToolOutput(output)
% parseToolOutput - The checksum in the output of the MD5 tool of this system
%
%   md5 -q prints the checksum alone, and md5sum prints it before the file
%   name. certutil prints a line that names the file, the checksum on the
%   second line (with a space between bytes before Windows 8), and a line
%   that reports success. The file name is not searched for the checksum,
%   since a name can hold 32 hexadecimal characters too.

    lines = splitlines(strtrim(output));
    if ispc
        hash = erase(strtrim(lines(min(2, end))), " ");
    else
        hash = extractBefore(lines(1) + " ", " ");
    end
    hash = lower(hash);
end

function quoted = quoteForPosixShell(text)
% quoteForPosixShell - Text as one single-quoted word of a POSIX shell
    quoted = "'" + replace(text, "'", "'\''") + "'";
end
