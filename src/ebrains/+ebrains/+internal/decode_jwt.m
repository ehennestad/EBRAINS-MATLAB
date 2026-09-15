function decodedPayload = decode_jwt(jwtToken)
    % decode_jwt - Decode a JSON Web token

    % Split the token into its components
    tokenParts = strsplit(jwtToken, '.');

    % Extract and decode the payload
    payloadBase64 = tokenParts{2};
    payloadBase64 = strrep(payloadBase64, '-', '+');
    payloadBase64 = strrep(payloadBase64, '_', '/');
    padding = mod(length(payloadBase64), 4);
    if padding > 0
        payloadBase64 = [payloadBase64, repmat('=', 1, 4 - padding)];
    end
    % base64decode rather than javax.xml.bind.DatatypeConverter: the Java
    % class needs a running JVM and lives in a package that was removed
    % from the JDK in Java 11, so it is not available in every MATLAB.
    payloadBytes = matlab.net.base64decode(payloadBase64);
    payloadJSON = native2unicode(payloadBytes, 'UTF-8');

    % Ensure json payload is a row vector
    payloadJSON = reshape(payloadJSON, 1, []);

    % Parse the JSON payload
    decodedPayload = jsondecode(payloadJSON);
end
