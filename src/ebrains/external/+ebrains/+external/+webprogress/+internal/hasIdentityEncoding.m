function tf = hasIdentityEncoding(response)
%hasIdentityEncoding - Return whether the body of a response has no content coding
%   TF = ebrains.external.webprogress.internal.hasIdentityEncoding(RESPONSE) is true when
%   RESPONSE has no Content-Encoding header field, or when the field names
%   the coding "identity". That coding means a body that was not
%   transformed. RFC 9110 reserves the token for Accept-Encoding, and RFC
%   2616 defined it as a content coding, which is why a server may still
%   send it in Content-Encoding. The byte count of such a body matches the
%   bytes saved to a file, which a body with a coding such as gzip does
%   not, because the HTTP client decodes it while it is saved.
%
%   This function is used by ebrains.external.webprogress.download.

    arguments
        response (1,1) matlab.net.http.ResponseMessage
    end

    field = response.getFields("Content-Encoding");
    tf = isempty(field) || strcmpi(strtrim(string(field(end).Value)), "identity");
end
