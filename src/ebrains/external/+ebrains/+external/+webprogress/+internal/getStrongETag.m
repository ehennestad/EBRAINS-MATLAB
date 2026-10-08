function entityTag = getStrongETag(response)
%getStrongETag - Return the strong entity tag of a response, or ""
%   ETAG = ebrains.external.webprogress.internal.getStrongETag(RESPONSE) returns the value
%   of the ETag header field of RESPONSE, quotes included, or "" when
%   the response has no such field or the entity tag is weak. An entity
%   tag is weak when it starts with "W/" (RFC 9110, section 8.8.3). Only
%   a strong one tells that two responses carry the same bytes, which
%   If-Range needs (section 13.1.5).
%
%   This function is used by ebrains.external.webprogress.download.

    arguments
        response (1,1) matlab.net.http.ResponseMessage
    end

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
