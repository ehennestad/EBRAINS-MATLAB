function decodedPayload = decode_jwt(jwtToken)
    % decode_jwt - Decode a JSON Web token
    %
    % Syntax:
    %   payload = ebrains.internal.decode_jwt(jwtToken) returns the payload
    %   of the JSON Web Token jwtToken as a struct. The signature is not
    %   verified: the payload is read for the claims the toolbox needs, such
    %   as the expiry time, from a token the identity provider issued or the
    %   user provided.
    %
    % Note: A value that is not shaped like a token raises
    %   EBRAINS:IAM:MalformedToken rather than the indexing or parse error of
    %   whichever step first trips over it. Such a value usually comes from
    %   the EBRAINS_TOKEN environment variable, which those errors would not
    %   name.

    arguments
        jwtToken (1,1) string
    end

    % A JWT is header.payload.signature, each part base64url-encoded
    tokenParts = strsplit(jwtToken, '.');
    if numel(tokenParts) ~= 3
        error('EBRAINS:IAM:MalformedToken', ...
            ['The access token is not a JSON Web Token: it has %d ', ...
            'dot-separated parts where a token has three.'], numel(tokenParts))
    end

    % Extract and decode the payload
    payloadBase64 = tokenParts{2};
    payloadBase64 = strrep(payloadBase64, '-', '+');
    payloadBase64 = strrep(payloadBase64, '_', '/');
    padding = mod(length(payloadBase64), 4);
    if padding > 0
        payloadBase64 = [payloadBase64, repmat('=', 1, 4 - padding)];
    end

    try
        % base64decode rather than javax.xml.bind.DatatypeConverter: the Java
        % class needs a running JVM and lives in a package that was removed
        % from the JDK in Java 11, so it is not available in every MATLAB.
        payloadBytes = matlab.net.base64decode(payloadBase64);
        payloadJSON = native2unicode(payloadBytes, 'UTF-8');

        % Ensure json payload is a row vector
        payloadJSON = reshape(payloadJSON, 1, []);

        % Parse the JSON payload
        decodedPayload = jsondecode(payloadJSON);
    catch cause
        exception = MException('EBRAINS:IAM:MalformedToken', ...
            'The payload of the access token is not base64url-encoded JSON.');
        throw(exception.addCause(cause))
    end
end
