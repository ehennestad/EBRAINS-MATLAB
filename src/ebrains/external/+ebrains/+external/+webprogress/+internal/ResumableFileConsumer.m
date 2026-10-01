classdef ResumableFileConsumer < matlab.net.http.io.FileConsumer
%ResumableFileConsumer - Write a response body to a partial file that can be resumed
%   consumer = ebrains.external.webprogress.internal.ResumableFileConsumer(PARTFILE,
%   STATEFILE, OFFSET) writes the body of a response to PARTFILE. OFFSET
%   is the start of the byte range that the request asked for, or 0 for a
%   request without a Range header. The file consumer appends the body
%   to PARTFILE, and the response status decides what happens first:
%       206 - The body is appended to PARTFILE when the Content-Range of
%             the response starts at OFFSET.
%       200 - PARTFILE is replaced by the body, and STATEFILE is written
%             with the validator and length of the new response.
%   A response with any other status leaves both files unchanged, and
%   its body goes to the response message as without a consumer.
%
%   STATEFILE holds the strong validator of the file, as ETag or
%   Last-Modified, and its total length. It never holds the URL, which
%   for a presigned URL carries a signature.
%
%   This class is used by ebrains.external.webprogress.download.

%   Written by Eivind Hennestad

    properties (SetAccess = immutable)
        PartFilePath  string % File that receives the body
        StateFilePath string % File that holds the validator and total length
        RequestedOffset (1,1) double % Start of the requested byte range
    end

    properties (SetAccess = private)
        WriteOffset (1,1) double = 0   % Size of the partial file the body is written after
        TotalBytes (1,1) double = nan  % Length of the complete file, if the response gives it
        RejectReason string = ""       % Why a 206 response was not accepted
    end

    properties
        % Progress monitor of the transfer. Its StartBytes is set to
        % WriteOffset when the response arrives.
        ProgressMonitor = []
    end

    methods
        function obj = ResumableFileConsumer(partFilePath, stateFilePath, requestedOffset)
            arguments
                partFilePath    (1,1) string
                stateFilePath   (1,1) string
                requestedOffset (1,1) double {mustBeNonnegative, mustBeInteger}
            end
            % Permission 'a' appends to an existing file, and initialize
            % empties the file first when the body replaces it.
            obj@matlab.net.http.io.FileConsumer(char(partFilePath), 'a');
            obj.PartFilePath = partFilePath;
            obj.StateFilePath = stateFilePath;
            obj.RequestedOffset = requestedOffset;
        end
    end

    methods (Access = protected)
        function ok = initialize(obj)
        %initialize - Accept the body of a 200 or a matching 206 response
        %   MATLAB calls initialize when the response header arrives, and
        %   sends the body to putData only when it returns true. The file
        %   consumer accepts a body whatever the status, so its decision
        %   counts only for a status whose body belongs in the file.
            response = obj.Response;
            statusCode = double(response.StatusCode);
            ok = false;

            if statusCode == 206
                [rangeStart, totalBytes] = parseContentRange(response);
                if rangeStart ~= obj.RequestedOffset
                    obj.RejectReason = sprintf("The server sent the file from byte %d " + ...
                        "instead of byte %d.", rangeStart, obj.RequestedOffset);
                    return
                end
                % A byte range applies to the representation as it is
                % sent, after any content coding (RFC 9110, sections 8.4
                % and 14.1). A decoded body cannot be appended at an
                % offset counted in encoded bytes.
                if ~hasIdentityEncoding(response)
                    obj.RejectReason = "The server sent the part of the file " + ...
                        "in a compressed form, which cannot be appended to the partial file.";
                    return
                end
                obj.WriteOffset = obj.RequestedOffset;
                obj.TotalBytes = totalBytes;
                ok = initialize@matlab.net.http.io.FileConsumer(obj);

            elseif statusCode == 200
                % Replace the partial file before the state file, so that
                % an interruption between the two never pairs old data
                % with the validator of a new file.
                fclose(openFile(obj.PartFilePath, 'w'));
                obj.WriteOffset = 0;
                obj.TotalBytes = getContentLength(response);
                obj.writeState(response)
                ok = initialize@matlab.net.http.io.FileConsumer(obj);
            end

            monitor = obj.ProgressMonitor;
            if ok && ~isempty(monitor) && isvalid(monitor)
                monitor.StartBytes = obj.WriteOffset;
            end
        end
    end

    methods (Access = private)
        function writeState(obj, response)
        %writeState - Save the validator and length of a 200 response
        %   Without a strong validator, or for a body that was decoded
        %   from a content coding, the partial file cannot be resumed, so
        %   no state file is kept.
            validator = "";
            if hasIdentityEncoding(response)
                validator = getStrongValidator(response);
            end

            if strlength(validator) == 0
                if isfile(obj.StateFilePath)
                    delete(obj.StateFilePath)
                end
                return
            end

            state = struct('Validator', validator, 'TotalBytes', obj.TotalBytes);
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

function [rangeStart, totalBytes] = parseContentRange(response)
    %parseContentRange - Return the first byte and complete length of a 206 response
    %   Content-Range has the form "bytes FIRST-LAST/COMPLETE", where
    %   COMPLETE is "*" when the server does not know the length (RFC 9110,
    %   section 14.4). A 206 response to a single range carries this field
    %   (section 15.3.7). rangeStart is NaN when the field is missing or
    %   malformed, and totalBytes is NaN for an unknown length.
    rangeStart = nan;
    totalBytes = nan;
    field = response.getFields("Content-Range");
    if isempty(field)
        return
    end
    tokens = regexp(char(field(end).Value), ...
        '^\s*bytes\s+(\d+)-\d+/(\d+|\*)\s*$', 'tokens', 'once');
    if isempty(tokens)
        return
    end
    rangeStart = str2double(tokens{1});
    totalBytes = str2double(tokens{2});
end

function totalBytes = getContentLength(response)
    %getContentLength - Return the Content-Length of a response, or NaN
    %   The length counts the bytes as sent, so it is the file size only
    %   for a body without a content coding.
    totalBytes = nan;
    field = response.getFields("Content-Length");
    if ~isempty(field) && hasIdentityEncoding(response)
        totalBytes = double(field(end).convert());
    end
end

function tf = hasIdentityEncoding(response)
    %hasIdentityEncoding - Return whether the body has no content coding
    %   RFC 2616 defined "identity" as a content coding, so a server may
    %   still name it in Content-Encoding.
    field = response.getFields("Content-Encoding");
    tf = isempty(field) || strcmpi(strtrim(string(field(end).Value)), "identity");
end

function validator = getStrongValidator(response)
    %getStrongValidator - Return a validator that If-Range can carry, or ""
    %   If-Range needs a strong validator (RFC 9110, section 13.1.5). An
    %   entity tag is weak when it starts with "W/" (section 8.8.3). A
    %   Last-Modified date is used only without an entity tag, and only
    %   when it is strong: at least one second before the Date of the
    %   response (section 8.8.2.2).
    validator = "";

    tagField = response.getFields("ETag");
    if ~isempty(tagField)
        entityTag = strtrim(string(tagField(end).Value));
        if ~startsWith(entityTag, "W/")
            validator = entityTag;
        end
        return
    end

    modifiedField = response.getFields("Last-Modified");
    dateField = response.getFields("Date");
    if isempty(modifiedField) || isempty(dateField)
        return
    end
    lastModified = strtrim(string(modifiedField(end).Value));
    modifiedTime = parseHttpDate(lastModified);
    responseTime = parseHttpDate(strtrim(string(dateField(end).Value)));
    if seconds(responseTime - modifiedTime) >= 1
        validator = lastModified;
    end
end

function time = parseHttpDate(text)
    %parseHttpDate - Convert an IMF-fixdate such as "Sun, 06 Nov 1994 08:49:37 GMT"
    %   Senders must generate this format (RFC 9110, section 5.6.7). Text
    %   in another format gives NaT, which fails every comparison.
    try
        time = datetime(text, 'InputFormat', 'eee, dd MMM yyyy HH:mm:ss ''GMT''', ...
            'Locale', 'en_US', 'TimeZone', 'UTC');
    catch
        time = NaT('TimeZone', 'UTC');
    end
end
