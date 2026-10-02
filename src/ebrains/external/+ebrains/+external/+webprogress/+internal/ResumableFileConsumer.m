classdef ResumableFileConsumer < matlab.net.http.io.FileConsumer
%ResumableFileConsumer - Write a response body to a partial file that can be resumed
%   consumer = ebrains.external.webprogress.internal.ResumableFileConsumer(PARTFILE,
%   STATEFILE, OFFSET, ETAG, TOTALBYTES) writes the body of a response to
%   PARTFILE. OFFSET is the start of the byte range that the request asked
%   for, or 0 for a request without a Range header. ETAG and TOTALBYTES
%   are the entity tag and length of the file the bytes in PARTFILE came
%   from, as saved in STATEFILE, or "" and NaN for a request without a
%   Range header. The file consumer appends the body to PARTFILE, and the
%   response status decides what happens first:
%       206 - The body is appended to PARTFILE when the response carries
%             the entity tag ETAG, its Content-Range starts at OFFSET and
%             gives TOTALBYTES or an unknown length, and the body has no
%             content coding. A different entity tag, start or length
%             raises the error webprogress:download:RestartRequired,
%             which ends the transfer before the body is received, so
%             that the caller can download the file from the beginning.
%       200 - PARTFILE is replaced by the body, and STATEFILE is written
%             with the entity tag and length of the new response, or
%             deleted when the response has no strong entity tag.
%   A body with a content coding raises an error for either status. A
%   response with any other status leaves both files unchanged, and its
%   body goes to the response message as without a consumer.
%
%   After the response, ExpectedBytes is the size PARTFILE has when the
%   whole body arrived, and TotalBytes is the length of the complete
%   file. Each is NaN when the response does not give it.
%
%   STATEFILE holds the strong entity tag of the file and its total
%   length. It never holds the URL, which for a presigned URL carries a
%   signature.
%
%   This class is used by ebrains.external.webprogress.download.

%   Written by Eivind Hennestad

    properties (SetAccess = immutable)
        PartFilePath  string % File that receives the body
        StateFilePath string % File that holds the entity tag and total length
        RequestedOffset (1,1) double % Start of the requested byte range
        ExpectedETag string          % Entity tag of the file the partial file belongs to
        ExpectedTotalBytes (1,1) double % Length of the file the partial file belongs to
    end

    properties (SetAccess = private)
        WriteOffset (1,1) double = 0     % Size of the partial file the body is written after
        ExpectedBytes (1,1) double = nan % Size of the partial file after the whole body
        TotalBytes (1,1) double = nan    % Length of the complete file
    end

    properties
        % Progress monitor of the transfer. Its StartBytes is set to
        % WriteOffset when the response arrives.
        ProgressMonitor = []
    end

    methods
        function obj = ResumableFileConsumer(partFilePath, stateFilePath, ...
                requestedOffset, expectedETag, expectedTotalBytes)
            arguments
                partFilePath       (1,1) string
                stateFilePath      (1,1) string
                requestedOffset    (1,1) double {mustBeNonnegative, mustBeInteger}
                expectedETag       (1,1) string
                expectedTotalBytes (1,1) double
            end
            % Permission 'a' appends to an existing file, and initialize
            % empties the file first when the body replaces it.
            obj@matlab.net.http.io.FileConsumer(char(partFilePath), 'a');
            obj.PartFilePath = partFilePath;
            obj.StateFilePath = stateFilePath;
            obj.RequestedOffset = requestedOffset;
            obj.ExpectedETag = expectedETag;
            obj.ExpectedTotalBytes = expectedTotalBytes;
        end
    end

    methods (Access = protected)
        function ok = initialize(obj)
        %initialize - Accept the body of a 200 or a matching 206 response
        %   MATLAB calls initialize when the response header arrives, and
        %   sends the body to putData only when it returns true. The file
        %   consumer accepts a body whatever the status, so its decision
        %   counts only for a status whose body belongs in the file. An
        %   error raised here ends the transfer, so the body is not
        %   received into memory as a refused body would be.
            response = obj.Response;
            statusCode = double(response.StatusCode);
            ok = false;

            if ~any(statusCode == [200, 206])
                return
            end

            % A byte range applies to the representation as it is sent,
            % after any content coding (RFC 9110, sections 8.4 and 14.1),
            % and the HTTP client decodes the body while it is saved. The
            % request asks for no coding, so a coded body is not expected
            % for either status, and the saved size of such a body could
            % not be checked or continued.
            if ~ebrains.external.webprogress.internal.hasIdentityEncoding(response)
                error("webprogress:download:ContentEncoded", ...
                    "Cannot save the download because the server sent the file in a " + ...
                    "compressed form, which cannot be resumed. Download it without " + ...
                    "Resume=true.")
            end

            if statusCode == 206
                obj.assertContinuesPartialFile(response)
                [~, lastByte, completeLength] = ...
                    ebrains.external.webprogress.internal.parseContentRange(response);
                obj.WriteOffset = obj.RequestedOffset;
                obj.ExpectedBytes = lastByte + 1;
                obj.TotalBytes = completeLength;
            else
                totalBytes = ebrains.external.webprogress.internal.getDeclaredLength(response);
                % Replace the partial file before the state file, so that
                % an interruption between the two never pairs old data
                % with the entity tag of a new file.
                fclose(openFile(obj.PartFilePath, 'w'));
                obj.WriteOffset = 0;
                obj.ExpectedBytes = totalBytes;
                obj.TotalBytes = totalBytes;
                obj.writeState(response)
            end
            ok = initialize@matlab.net.http.io.FileConsumer(obj);

            monitor = obj.ProgressMonitor;
            if ok && ~isempty(monitor) && isvalid(monitor)
                monitor.StartBytes = obj.WriteOffset;
            end
        end
    end

    methods (Access = private)
        function assertContinuesPartialFile(obj, response)
        %assertContinuesPartialFile - Raise an error if a 206 response does not continue the file
        %   The server may ignore If-Range and send a range of a changed
        %   file, so the entity tag of the response is compared with the
        %   saved one. A 206 response to a single range carries
        %   Content-Range (RFC 9110, section 15.3.7), which must start
        %   where the partial file ends and, when it gives the complete
        %   length, give the saved one.
            entityTag = getStrongETag(response);
            if entityTag ~= obj.ExpectedETag
                obj.raiseRestartRequired("The file on the server has changed.")
            end

            [firstByte, ~, completeLength] = ...
                ebrains.external.webprogress.internal.parseContentRange(response);
            if firstByte ~= obj.RequestedOffset
                obj.raiseRestartRequired(sprintf( ...
                    "The server sent the file from byte %d instead of byte %d.", ...
                    firstByte, obj.RequestedOffset))
            end
            if ~isnan(completeLength) && completeLength ~= obj.ExpectedTotalBytes
                obj.raiseRestartRequired(sprintf( ...
                    "The file on the server has %d bytes instead of %d.", ...
                    completeLength, obj.ExpectedTotalBytes))
            end
        end

        function raiseRestartRequired(obj, reason)
        %raiseRestartRequired - Raise the error that tells the caller to start over
            error("webprogress:download:RestartRequired", ...
                "The partial file ""%s"" cannot be continued. %s", obj.PartFilePath, reason)
        end

        function writeState(obj, response)
        %writeState - Save the entity tag and length of a 200 response
        %   Without a strong entity tag the partial file cannot be
        %   resumed, so no state file is kept.
            entityTag = getStrongETag(response);
            if strlength(entityTag) == 0
                if isfile(obj.StateFilePath)
                    delete(obj.StateFilePath)
                end
                return
            end

            state = struct('ETag', entityTag, 'TotalBytes', obj.TotalBytes);
            fileId = openFile(obj.StateFilePath, 'w');
            fileCleanup = onCleanup(@() fclose(fileId));
            fwrite(fileId, jsonencode(state), 'char');
        end
    end
end

function fileId = openFile(filePath, permission)
    %openFile - Open a file and raise an error if it cannot be opened
    [fileId, message] = fopen(filePath, permission);
    if fileId < 0
        error("webprogress:download:CannotSaveFile", ...
            "Cannot write the downloaded data to ""%s"": %s", filePath, message)
    end
end

function entityTag = getStrongETag(response)
    %getStrongETag - Return the strong entity tag of a response, or ""
    %   An entity tag is weak when it starts with "W/" (RFC 9110, section
    %   8.8.3). Only a strong one tells that two responses carry the same
    %   bytes, which If-Range needs (section 13.1.5).
    entityTag = "";
    tagField = response.getFields("ETag");
    if isempty(tagField)
        return
    end
    value = strtrim(string(tagField(end).Value));
    if ~startsWith(value, "W/")
        entityTag = value;
    end
end
