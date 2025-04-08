function metadataInstances = downloadInstancesBulk(identifiers, stage, optionals)
% downloadInstancesBulk - Download a set of metadata instances given their uuids
% 
% Syntax:
%   metadataInstances = ebrains.kg.api.downloadInstancesBulk(identifier, stage, optionals)
%   Downloads a set of metadata instances from KG given a list of identifiers,
%   stage, and optional parameters for additional configurations.
%
% Input Arguments:
%   identifiers string     - List of unique identifiers of the instances to be downloaded.
%   stage (1,1) string     - The stage of the instances to retrieve; options include
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
%   metadataInstances      - The downloded metadata instances.

    % Todo: return response metadata as optional second arg
    arguments
        identifiers (1,:) string
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

    if isscalar(identifiers)
        nvPairs = namedargs2cell(optionals);
        metadataInstances = ebrains.kg.api.downloadInstance(identifiers, stage, nvPairs{:});
        return
    end

    BASE_API_URL = "https://core.kg.ebrains.eu/v3/instancesByIds/";

    authClient = ebrains.iam.AuthenticationClient.instance();
    authHeaderField = authClient.getAuthHeaderField();
    % Create header fields
    headers = [...
        matlab.net.http.HeaderField('Accept', '*/*'), ...
        authHeaderField, ...
        matlab.net.http.HeaderField('Content-Type', 'application/json')];
    
    for i = 1:numel(identifiers)
        if startsWith(identifiers(i), "https://kg.ebrains.eu/api/instances/")
             identifiers(i) = strrep(identifiers(i), "https://kg.ebrains.eu/api/instances/", "");
        end
    end

    method = matlab.net.http.RequestMethod.POST;
    body = matlab.net.http.MessageBody(identifiers);
    
    apiURL = BASE_API_URL;
    queryNames = fieldnames(optionals);
    queryValues = struct2cell(optionals);
    queryNameValuePairs = [queryNames'; queryValues'];
    fullApiURL = matlab.net.URI(apiURL, "stage", stage(1), queryNameValuePairs{:});
    
    req = matlab.net.http.RequestMessage(method, headers, body);
    response = req.send(fullApiURL);

    if response.StatusCode == "OK"
        [metadataInstances, missingIds] = processResponse(response);
        if ~isempty(missingIds)
            metadataInstances(cellfun('isempty', metadataInstances)) = [];

            if numel(stage) == 2
                metadataInstancesInProgress = ebrains.kg.api.downloadInstancesBulk(missingIds, "IN_PROGRESS");
                metadataInstances = [metadataInstances, metadataInstancesInProgress];
            else
                missingIdsConcatenated = strjoin("  " + string(missingIds), newline);
                otherStage = setdiff(["RELEASED", "IN_PROGRESS"], stage);
                warning(['Failed to retrieve the following instances:\n%s\n', ...
                    'Please try downloading using stage %s instead\n'], missingIdsConcatenated, otherStage)
            end
        end
    else
        error("%s: %s", response.StatusCode, response.Body)
    end

    if response.StatusCode ~= "OK"
        error(response.string) % todo: improve error message
    end
end


function [metadataInstances, missingIds] = processResponse(response)
    data = struct2cell(response.Body.Data.data);

    missingIds = string.empty;
    numInstances = numel(data);
    metadataInstances = cell(1, numInstances);
    
    for i = 1:numInstances
        if ~isempty(data{i}.error)
            missingIds(end+1)=string(data{i}.error.message); %#ok<AGROW>
        end
        metadataInstances{i} = data{i}.data;
    end
end
