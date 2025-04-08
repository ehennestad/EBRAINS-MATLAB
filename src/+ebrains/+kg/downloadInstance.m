function instanceData = downloadInstance(identifier, stage, optionals)
    arguments
        identifier string
        stage (1,1) string { mustBeMember(stage,["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
        optionals.returnIncomingLinks logical %= false
        optionals.incomingLinksPageSize int64 %= 10
        optionals.returnPayload logical %= true
        optionals.returnPermissions logical %= false
        optionals.returnAlternatives logical %= false
        optionals.returnEmbedded logical %= true
    end

    if stage == "ANY"
        stage = ["RELEASED", "IN_PROGRESS"];
    end

    BASE_API_URL = "https://core.kg.ebrains.eu/v3/instances/";

    authClient = ebrains.iam.AuthenticationClient.instance();
    authHeaderField = authClient.getAuthHeaderField();

    if startsWith(identifier, "https://kg.ebrains.eu/api/instances/")
         identifier = strrep(identifier, "https://kg.ebrains.eu/api/instances/", "");
    end

    apiURL = BASE_API_URL + "/" + identifier;
    
    queryNames = fieldnames(optionals);
    queryValues = struct2cell(optionals);
    queryNameValuePairs = [queryNames; queryValues];

    for i=1:numel(stage)
        fullApiURL = matlab.net.URI(apiURL, "stage", stage(i), queryNameValuePairs{:});
        
        method = matlab.net.http.RequestMethod.GET;
        req = matlab.net.http.RequestMessage(method, authHeaderField, []);
    
        response = req.send(fullApiURL);
    
        if response.StatusCode == "OK"
            instanceData = response.Body.Data.data;
            break
        end
    end

    if response.StatusCode ~= "OK"
        error(response.string) % todo: improve error message
    end
end
