classdef FileRangeProvider < matlab.net.http.io.ContentProvider
%FileRangeProvider - Send a byte range of a file as the body of a request
%   provider = ebrains.external.webprogress.internal.FileRangeProvider(FILENAME, OFFSET,
%   NUMBYTES) sends NUMBYTES bytes of the file FILENAME, starting OFFSET
%   bytes into the file. The file is read in buffers, so a range of any
%   size is sent without holding it in memory.
%
%   The provider announces NUMBYTES as the length of the body, so the
%   request carries a Content-Length header instead of a chunked body.
%   Each request reads the range from its start, so the same provider
%   can send the range again.
%
%   This class is used by ebrains.external.webprogress.upload.

%   Written by Eivind Hennestad

    properties (SetAccess = immutable)
        FilePath string        % File to read the range from
        Offset   (1,1) double  % Number of bytes before the range
        NumBytes (1,1) double  % Number of bytes in the range
    end

    properties (Access = private)
        FileId = -1        % Identifier of the open file
        SentBytes = 0      % Bytes of the range given to the current request
    end

    methods
        function obj = FileRangeProvider(filePath, offset, numBytes)
            arguments
                filePath (1,1) string {mustBeFile}
                offset   (1,1) double {mustBeNonnegative, mustBeInteger}
                numBytes (1,1) double {mustBeNonnegative, mustBeInteger}
            end
            obj.FilePath = filePath;
            obj.Offset = offset;
            obj.NumBytes = numBytes;
        end

        function [data, stop] = getData(obj, requestedLength)
        %getData - Return the next buffer of the range
        %   MATLAB calls getData until stop is true. The first call of a
        %   request opens the file at the start of the range.
            if obj.FileId < 0
                obj.openAtOffset()
            end

            bytesToRead = min(double(requestedLength), obj.NumBytes - obj.SentBytes);
            [data, count] = fread(obj.FileId, bytesToRead, '*uint8');
            if count < bytesToRead
                obj.closeFile()
                error("webprogress:upload:FileChanged", ...
                    "Cannot send bytes %d to %d of ""%s"" because the file ended after " + ...
                    "%d bytes. Check that the file is not changed during the upload.", ...
                    obj.Offset, obj.Offset + obj.NumBytes - 1, obj.FilePath, ...
                    obj.Offset + obj.SentBytes + count)
            end

            obj.SentBytes = obj.SentBytes + count;
            stop = obj.SentBytes >= obj.NumBytes;
            if stop
                obj.closeFile()
            end
        end

        function delete(obj)
            obj.closeFile()
        end
    end

    methods (Access = protected)
        function start(obj)
        %start - Prepare to send the range from its first byte
            start@matlab.net.http.io.ContentProvider(obj)
            obj.closeFile()
            obj.SentBytes = 0;
        end

        function len = expectedContentLength(obj, ~)
        %expectedContentLength - Return the number of bytes in the range
            len = obj.NumBytes;
        end

        function tf = restartable(~)
        %restartable - Return true, because each request rereads the range
            tf = true;
        end

        function tf = reusable(~)
        %reusable - Return true, because each request rereads the range
            tf = true;
        end
    end

    methods (Access = private)
        function openAtOffset(obj)
        %openAtOffset - Open the file and move to the start of the range
            [fileId, message] = fopen(obj.FilePath, 'r');
            if fileId < 0
                error("webprogress:upload:CannotReadFile", ...
                    "Cannot read ""%s"": %s", obj.FilePath, message)
            end
            obj.FileId = fileId;
            obj.SentBytes = 0;
            if fseek(fileId, obj.Offset, 'bof') ~= 0
                message = ferror(fileId);
                obj.closeFile()
                error("webprogress:upload:CannotReadFile", ...
                    "Cannot move to byte %d of ""%s"": %s", obj.Offset, obj.FilePath, message)
            end
        end

        function closeFile(obj)
        %closeFile - Close the file if it is open
            if obj.FileId >= 0
                fclose(obj.FileId);
                obj.FileId = -1;
            end
        end
    end
end
