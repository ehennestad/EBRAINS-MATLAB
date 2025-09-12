function throwError(operationName, responseObject, server)

    arguments
        operationName (1,1) string
        responseObject
        server (1,1) ebrains.kg.enum.KGServer
    end

    errorID = sprintf('EBRAINS:KG_API:%s:%s', operationName, responseObject.StatusCode);

    if responseObject.StatusCode == 500
        errorDescription = sprintf('Something went wrong. Please verify that the KG server (%s) is working.', server.Name);
    else
        if isfield(responseObject.StatusCode, 'Data')
            errorDescription = responseObject.StatusCode.Data;
        else
            errorDescription = char(responseObject.Body);
        end
    end

    ME = MException(errorID, '%s: %s', char(responseObject.StatusCode), errorDescription);
    throwAsCaller(ME)
end
