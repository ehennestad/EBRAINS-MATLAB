function downloadControlledInstanceIdentifiers()
% downloadControlledInstanceIdentifiers - Download KG uuids and openMINDS
% @ids for controlled instances

    % Use api client to list all types in the controlled space
    apiClient = ebrains.kgcore.api.Basic();
    [~, response] = apiClient.listTypes("RELEASED", "space", "controlled");
    
    % Extract the type name, but only for controlled term types
    controlledTermTypes = string.empty;
    for i = 1:numel(response.data)
        thisData = response.data{i};
        if startsWith(thisData.http___schema_org_identifier, ...
                "https://openminds.ebrains.eu/controlledTerms/")
            controlledTermTypes(end+1) = thisData.http___schema_org_identifier; %#ok<AGROW>
        end
    end
    
    % Download all the instances of each type and retrieve the identifiers
    numTypes = numel(controlledTermTypes);
    instanceUuidListing = cell(1, numTypes);
    for i = 1:numTypes
        fprintf('Fetching information for "%s"\n', controlledTermTypes{i})
        [~, response] = apiClient.listInstances("RELEASED", controlledTermTypes{i}, "space", "controlled");
        instanceUuidListing{i} = processInstanceResponse(response);
    end

    identifierMap = [instanceUuidListing{:}]; 

    mapFilepath = fullfile(...
        ebrains.common.namespacedir('ebrains.kg'), ...
        'resources', ...
        'kg2om_identifier_loopkup.json');

    utility.filewrite(mapFilepath, jsonencode(identifierMap, 'PrettyPrint', true))
end

function result = processInstanceResponse(instanceResponse)
% processInstanceResponse - Extract KG uuids and openMINDS identifiers from response data
    numInstances = numel(instanceResponse.data);
    [kgIds, omIds] = deal(cell(1, numInstances));
    for j = 1:numel(instanceResponse.data)
        thisData = instanceResponse.data(j);
        if iscell(thisData)
            thisData = thisData{1};
        end
        kgIds{j} = string(thisData.x_id);

        schemaIds = thisData.http___schema_org_identifier;
        isOpenMindsIdentifier = startsWith(schemaIds, 'https://openminds');
        if any(isOpenMindsIdentifier)
            assert(sum(isOpenMindsIdentifier)==1, 'Expected single match for openMINDS @id.')
            omIds{j} = string(schemaIds(isOpenMindsIdentifier));
        else
            omIds{j} = "";
        end
    end
    result = struct('kg', kgIds, 'om', omIds);
end
