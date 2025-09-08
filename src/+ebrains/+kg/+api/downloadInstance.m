function metadataInstance = downloadInstance(identifier, stage, optionals, serverOpts)
% downloadInstance - Downloads KG metadata instance for the given identifier.
%
% Syntax:
%   metadataInstance = ebrains.kg.api.downloadInstance(identifier, stage, optionals)
%   Downloads instance data from the API using the specified identifier,
%   stage, and optional parameters for additional configurations.
%
% Input Arguments:
%   identifier string      - The unique identifier of the instance to be downloaded.
%   stage (1,1) string     - The stage of the instance to retrieve; options include
%                            "IN_PROGRESS", "RELEASED", or "ANY". Defaults to "ANY".
%   optionals              - Optional structure with the following fields:
%       returnIncomingLinks logical   - If true, return incoming links; default is false.
%       incomingLinksPageSize int64   - Number of incoming links to return per page; default is 10.
%       returnPayload logical         - If true, return the payload; default is true.
%       returnPermissions logical     - If true, return permissions; default is false.
%       returnAlternatives logical    - If true, return alternatives; default is false.
%       returnEmbedded logical        - If true, return embedded data; default is true.
%
% Output Arguments:
%   metadataInstance        - The downloaded metadata instance.

    arguments
        identifier string
        stage (1,1) string { mustBeMember(stage, ["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
        optionals.returnIncomingLinks logical %= false
        optionals.incomingLinksPageSize int64 %= 10
        optionals.returnPayload logical %= true
        optionals.returnPermissions logical %= false
        optionals.returnAlternatives logical %= false
        optionals.returnEmbedded logical %= true
        serverOpts.Server (1,1) string {mustBeMember(serverOpts.Server, ["prod", "preprod"])} = "prod"
    end
    
    if stage == "ANY"
        stage = ["RELEASED", "IN_PROGRESS"];
    end

    serverUrl = ebrains.common.constant.KGCoreApiBaseURL("Server", serverOpts.Server);
    baseApiUrl = serverUrl + "/instances";
    
    authClient = ebrains.iam.AuthenticationClient.instance();
    authHeaderField = authClient.getAuthHeaderField();

    if startsWith(identifier, "https://kg.ebrains.eu/api/instances/")
         identifier = strrep(identifier, "https://kg.ebrains.eu/api/instances/", "");
    end

    apiURL = baseApiUrl + "/" + identifier;
    
    queryNames = fieldnames(optionals);
    queryValues = struct2cell(optionals);
    queryNameValuePairs = [queryNames'; queryValues'];

    for i=1:numel(stage)
        fullApiURL = matlab.net.URI(apiURL, "stage", stage(i), queryNameValuePairs{:});
        
        method = matlab.net.http.RequestMethod.GET;
        req = matlab.net.http.RequestMessage(method, authHeaderField, []);
    
        response = req.send(fullApiURL);
    
        if response.StatusCode == "OK"
            metadataInstance = response.Body.Data.data;
            break
        end
    end

    if response.StatusCode ~= "OK"
        error(response.string) % todo: improve error message
    end
end
