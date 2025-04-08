function [metadataInstance, metadataCollection] = downloadMetadata(identifier, options)

    arguments
        identifier (1,1) string
        % metadataCollection (1,1) openminds.Collection = openminds.Collection()
        options.NumLinksToResolve = 2
        options.CollectionTargetFile (1,1) string = missing
        options.Verbose (1,1) logical = true
    end

    controlledTermUuidMap = ebrains.kg.kg2openminds.internal.getIdentifierMapping();
    controlledTermKgIds = controlledTermUuidMap.keys();
    
    % Download instance
    kgNode = ebrains.kg.downloadInstance(identifier);
    
    kgIRI = ebrains.kg.internal.getNodeKeywords(kgNode, "id");
    rootNode = ebrains.kg.kg2openminds.internal.convertKgNode(kgNode);
    
    allNodes = {rootNode};
    resolvedIRIs = kgIRI;

    for i = 1:options.NumLinksToResolve
        
        linkedIRIs = ebrains.kg.kg2openminds.internal.extractLinkedIdentifiers(rootNode);
        linkedIRIs = setdiff(linkedIRIs, controlledTermKgIds);
        linkedIRIs = setdiff(linkedIRIs, resolvedIRIs);
        
        if options.Verbose
            fprintf(['Following links of %s order. ', ...
                'Please wait while downloading %d new metadata instances...\n'], ...
                orderStr(i), numel(linkedIRIs));
        end
        
        kgNodes = ebrains.kg.downloadInstancesBulk(linkedIRIs);
        newNodes = ebrains.kg.kg2openminds.internal.convertKgNode(kgNodes);

        allNodes = [allNodes, newNodes]; %#ok<AGROW>
        rootNode = newNodes;
        resolvedIRIs = [resolvedIRIs, linkedIRIs]; %#ok<AGROW>
    end
    
    % Replace all controlled instance uuids
    allNodes = ebrains.kg.kg2openminds.internal.replaceControlledInstanceIds(...
        allNodes, controlledTermUuidMap);
    
    % Todo: serialize to temp file, if not target file is supplier
    jsonInstance = openminds.internal.serializer.struct2jsonld(allNodes);
    filename = sprintf('%s_kg_metadata_download.jsonld', identifier);
    openminds.internal.utility.filewrite(filename, jsonInstance)
    
    metadataCollection = openminds.Collection(filename, 'LinkResolver', ebrains.kg.KGResolver());
    metadataInstance = metadataCollection.Nodes(kgIRI);
end

function result = orderStr(val)
    if val == 1
        result = sprintf('%dst', val);
    elseif val == 2
        result = sprintf('%dnd', val);
    elseif val == 3
        result = sprintf('%drd', val);
    else
        result = sprintf('%dth', val);
    end
end
