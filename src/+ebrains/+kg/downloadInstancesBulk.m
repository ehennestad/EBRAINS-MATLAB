function instanceData = downloadInstancesBulk(identifiers, stage, optionals)
    
    % Todo: return response metadata as optional second arg
    arguments
        identifiers (1,:) string {mustBeSpecifiedLength(identifiers, 2, 9999)}
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
    %body = matlab.net.http.MessageBody(identifiers);
    %jsonData = jsonencode([identifiers,identifiers] );
    
    body = matlab.net.http.MessageBody(identifiers);
    apiURL = BASE_API_URL;
    
    queryNames = fieldnames(optionals);
    queryValues = struct2cell(optionals);
    queryNameValuePairs = [queryNames; queryValues]; 

    for i = 1:numel(stage)
        fullApiURL = matlab.net.URI(apiURL, "stage", stage(i), queryNameValuePairs{:});
        
        req = matlab.net.http.RequestMessage(method, headers, body);
        response = req.send(fullApiURL);
    
        if response.StatusCode == "OK"
            [instanceData, missingIds] = processResponse(response);
            if ~isempty(missingIds)
                instanceData(cellfun('isempty', instanceData))=[];
                instanceDataInProgress = ebrains.kg.downloadInstancesBulk(missingIds, "IN_PROGRESS");
                instanceData = [instanceData, instanceDataInProgress]; %#ok<AGROW>
            end
            break
        end
    end

    if response.StatusCode ~= "OK"
        error(response.string) % todo: improve error message
    end
end

function [instanceData, missingIds] = processResponse(response)
    data = struct2cell(response.Body.Data.data);
    instanceIdentifiers = fieldnames(response.Body.Data.data);

    missingIds = string.empty;
    numInstances = numel(data);
    instanceData = cell(1, numInstances);
    
    for i = 1:numInstances
        if ~isempty(data{i}.error)
            warning('Something went wrong for instance: %s', instanceIdentifiers{i});
            missingIds(end+1)=string(data{i}.error.message); %#ok<AGROW>
        end
        instanceData{i} = data{i}.data;
    end
end
