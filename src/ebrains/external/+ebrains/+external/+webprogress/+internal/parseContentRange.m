function [firstByte, lastByte, completeLength] = parseContentRange(response)
%parseContentRange - Return the byte positions in the Content-Range of a 206 response
%   [FIRST, LAST, COMPLETE] = ebrains.external.webprogress.internal.parseContentRange(RESPONSE)
%   reads the Content-Range header field of RESPONSE, which a 206
%   response to a single range carries in the form "bytes FIRST-LAST/COMPLETE"
%   (RFC 9110, sections 14.4 and 15.3.7). COMPLETE is the length of the
%   whole file, or "*" when the server does not know it. Each output is
%   NaN when the field does not give it, or when the field is missing or
%   in another form.
%
%   This function is used by ebrains.external.webprogress.download.

%   Written by Eivind Hennestad

    firstByte = nan;
    lastByte = nan;
    completeLength = nan;

    field = response.getFields("Content-Range");
    if isempty(field)
        return
    end

    tokens = regexp(char(field(end).Value), ...
        '^\s*bytes\s+(\d+)-(\d+)/(\d+|\*)\s*$', 'tokens', 'once');
    if isempty(tokens)
        return
    end

    % str2double gives NaN for "*".
    firstByte = str2double(tokens{1});
    lastByte = str2double(tokens{2});
    completeLength = str2double(tokens{3});
end
