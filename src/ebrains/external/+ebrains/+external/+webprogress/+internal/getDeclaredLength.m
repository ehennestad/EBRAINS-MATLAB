function declaredBytes = getDeclaredLength(response)
%getDeclaredLength - Return the length that Content-Length announces for a body
%   N = ebrains.external.webprogress.internal.getDeclaredLength(RESPONSE) returns the value
%   of the Content-Length header field of RESPONSE, or NaN when the
%   response has no such field, as a chunked response does not.
%
%   A response with several Content-Length fields of different values is
%   invalid (RFC 9110, section 8.6), and the length of its body cannot be
%   known, so it is an error. Repeated fields with the same value count as
%   one.
%
%   This function is used by ebrains.external.webprogress.download.

%   Written by Eivind Hennestad

    declaredBytes = nan;

    lengthFields = response.getFields("Content-Length");
    if isempty(lengthFields)
        return
    end

    declaredBytes = unique(double(lengthFields.convert()));
    if ~isscalar(declaredBytes)
        error("webprogress:download:InvalidContentLength", ...
            "The server gave %d different lengths for the file (%s bytes), so the " + ...
            "download cannot be checked and the file was not saved. Try the download again.", ...
            numel(declaredBytes), strjoin(string(declaredBytes), ", "))
    end
end
