function renameObject(bucketName, objectName, targetName)
    arguments
        bucketName (1,1) string
        objectName (1,1) string
        targetName (1,1) string
    end

    if startsWith(objectName, '/')
        objectName = extractAfter(objectName, 1);
    end
    if startsWith(targetName, '/')
        targetName = extractAfter(targetName, 1);
    end

    requiredArgs = ebrains.dataproxy.models.RenameObjectPayload(...
        'rename', ...
        ebrains.dataproxy.models.RenameObjectSetting('target_name', targetName));

    bucketApiClient = ebrains.dataproxy.api.Buckets();
    [code, ~, response] = bucketApiClient.renameObject(...
        bucketName, objectName, requiredArgs);

    % code is a matlab.net.http.StatusCode enum, and string(code) yields
    % the status number rather than its name.
    if code ~= matlab.net.http.StatusCode.OK
        errorMessage = string(char(response.StatusCode));
        errorDescription = getResponseBodyText(response);
        if strlength(errorDescription) > 0
            errorMessage = errorMessage + ": " + errorDescription;
        end
        % Pass the message through a format specifier so that "%" or "\"
        % in the server's text is not interpreted by error().
        error('EBRAINS:Bucket:ObjectRenameFailed', '%s', errorMessage);
    end
end

function bodyText = getResponseBodyText(response)
% getResponseBodyText - Get the body of a response as text, or "" if none.
%
%   The API client sends requests with ConvertResponse=false, so the body
%   of a failed response arrives as JSON text. A response without a body
%   has an empty Body, so it is checked with isempty before reading Data.
    bodyText = "";
    if isempty(response.Body) || isempty(response.Body.Data)
        return
    end
    bodyData = response.Body.Data;
    if ischar(bodyData) || isstring(bodyData)
        bodyText = string(bodyData);
    end
end
