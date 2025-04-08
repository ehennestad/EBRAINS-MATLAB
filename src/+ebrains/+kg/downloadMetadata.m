function [metadataInstance, metadataCollection] = downloadMetadata(identifier, options)
% downloadMetadata - Downloads metadata from KG given a unique identifier
%
% Syntax:
%   [metadataInstance, metadataCollection] = ebrains.kg.downloadMetadata(identifier, options)
%
% Input Arguments:
%   identifier (1,1) string - The unique identifier for the metadata
%   options (1,1) struct - Struct containing options for downloading
%       options.NumLinksToResolve (1,1) double - Number of links to resolve (default: 2)
%       options.CollectionTargetFile (1,1) string - Target file for collection (default: missing)
%       options.Verbose (1,1) logical - Flag for verbose output (default: true)
%
% Output Arguments:
%   metadataInstance - The instance of the metadata corresponding to the identifier
%   metadataCollection - The collection of all downloaded metadata instances

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
    kgNode = ebrains.kg.api.downloadInstance(identifier);
    
    kgIRI = ebrains.kg.internal.getNodeKeywords(kgNode, "@id");
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
        
        kgNodes = ebrains.kg.api.downloadInstancesBulk(linkedIRIs);
        newNodes = ebrains.kg.kg2openminds.internal.convertKgNode(kgNodes);

        allNodes = [allNodes, newNodes]; %#ok<AGROW>
        rootNode = newNodes;
        resolvedIRIs = [resolvedIRIs, linkedIRIs]; %#ok<AGROW>
    end
    
    if options.Verbose
        fprintf('Done.\n');
    end

    % Replace all controlled instance uuids
    allNodes = ebrains.kg.kg2openminds.internal.replaceControlledInstanceIds(...
        allNodes, controlledTermUuidMap);
    
    % Todo: serialize to temp file, if not target file is supplier
    jsonInstance = openminds.internal.serializer.struct2jsonld(allNodes);
    if ismissing(options.CollectionTargetFile)
        filename = sprintf('%s_kg_metadata.jsonld', identifier);
        filePath = fullfile(tempdir, filename);
        fileCleanup = onCleanup(@() deleteFile(filePath));
    else
        filePath = options.CollectionTargetFile;
    end
    openminds.internal.utility.filewrite(filePath, jsonInstance);
    
    if options.Verbose
        fprintf('Creating a metadata collection with all the instances. Please wait a moment...\n')
    end

    metadataCollection = openminds.Collection(filePath, 'LinkResolver', ebrains.kg.KGResolver());
    metadataInstance = metadataCollection.Nodes(kgIRI);

    if options.Verbose
        fprintf('Done.\n');
    end
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

function deleteFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end

