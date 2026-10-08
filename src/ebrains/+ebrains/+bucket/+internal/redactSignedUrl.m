function exception = redactSignedUrl(exception, signedUrl)
% redactSignedUrl - Remove the query string of a signed URL from an error
%
%   exception = ebrains.bucket.internal.redactSignedUrl(exception, signedUrl)
%   returns an MException with the identifier of the given one. In its
%   message, and in the messages of its causes, signedUrl appears without
%   its query string.
%
%   A temporary URL of the Data Proxy carries its signature in the query
%   string, so anyone who reads the whole URL can use it until it expires.
%   The HTTP client puts the whole URL in the message of an error such as
%   a refused connection or a timeout, and that message is shown on screen.

    arguments
        exception (1,1) MException
        signedUrl (1,1) string
    end

    if ~contains(signedUrl, "?")
        return
    end

    queryString = "?" + extractAfter(signedUrl, "?");
    message = strrep(string(exception.message), queryString, "");
    redactedException = MException(exception.identifier, "%s", message);
    for i = 1:numel(exception.cause)
        redactedCause = ebrains.bucket.internal.redactSignedUrl(exception.cause{i}, signedUrl);
        redactedException = redactedException.addCause(redactedCause);
    end
    exception = redactedException;
end
