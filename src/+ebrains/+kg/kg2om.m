function omInstance = kg2om(kgNode, options)

% todo: bulk download
    arguments
        kgNode
        options.ResolveLinksDepth = 0
        options.Collection = []
        options.Verbose (1,1) logical = true
    end

    numNodes = numel(kgNode);
    if numNodes > 1
        omInstance = cell(1, numNodes);
        for iProp = 1:numNodes
            omInstance{iProp} = ebrains.kg.kg2om( kgNode(iProp), ...
                "ResolveLinksDepth", options.ResolveLinksDepth);
        end
        try
            omInstance = [omInstance{:}];
        end
        return
    end

    if isfield(kgNode, 'http___schema_org_identifier')
        schemaOrgIdentifier = kgNode.http___schema_org_identifier;
        if any(startsWith(schemaOrgIdentifier, "https://openminds"))
            %omIdentifier = schemaOrgIdentifier{startsWith(schemaOrgIdentifier, "https://openminds")};
            %omInstance = openminds.fromIdentifier(omIdentifier);
            %return
        end
    end

    [identifier, type] = ebrains.kg.internal.getNodeKeywords(kgNode, "id", "type");
    if ~isempty(options.Collection)
        if options.Collection.isKey(identifier)
            omInstance = options.Collection.get(identifier);
            return
        end
    end

    omInstance = openminds.fromTypeName(type, identifier);

    omNode = ebrains.kg.kg2openminds.internal.filterData(kgNode);
    omNode = ebrains.kg.kg2openminds.internal.removeContextPrefix(omNode);

    propertyNames = fieldnames(omNode);
    propertyValues = struct2cell(omNode);

    for iProp = 1:numel(propertyNames)
        propertyName = propertyNames{iProp};
        propertyValue = propertyValues{iProp};

        if ~isprop(omInstance, propertyName)
            warning('"%s" is not a property for class "%s"', propertyName, class(omInstance));
            continue
        end

        if isLinkedNode(propertyValue)
            if options.ResolveLinksDepth > 0
                propertyValue = resolveLinkedNodes(propertyValue, ...
                     "ResolveLinksDepth", options.ResolveLinksDepth-1, ...
                     "Collection", options.Collection, ...
                     "TargetProperty", propertyName);
            else
                propertyValue = createUnresolvedNode(propertyValue, omInstance.(propertyName));
            end
        elseif isEmbeddedNode(propertyValue)
            propertyValue = ebrains.kg.kg2om(propertyValue, ...
                "ResolveLinksDepth", options.ResolveLinksDepth, ...
                "Collection", options.Collection);
        else
            % pass : value should not need processing
        end

        try
            if openminds.utility.isMixedInstance( omInstance.(propertyName) )
    
            else
                
            end
        catch
            keyboard
        end

        omInstance.(propertyName) = propertyValue;
    end
    if ~isempty(options.Collection)
        options.Collection.add(omInstance)
    end
end

function resolvedNodes = resolveLinkedNodes(nodes, options)
    arguments
        nodes
        options.ResolveLinksDepth = 0
        options.Collection = []
        options.TargetProperty = ""
    end

    numNodes = numel(nodes);

    [linkedNodes, resolvedNodes] = deal(cell(1, numNodes));
    for iNode = 1:numNodes
        thisNode = nodes(iNode);

        if ~isempty(options.Collection)
            if options.Collection.isKey(thisNode.x_id)
                resolvedNodes{iNode} = options.Collection.get(thisNode.x_id);
                continue
            end
        end

        if isControlledInstance(thisNode)
            %linkedNodes{iNode} = resolveControlledInstance(thisNode);
            fprintf('controlled\n')
            disp(propertyValue(iNode))
        else
            fprintf('Downloading "%s" with id %s\n', options.TargetProperty, thisNode.x_id)
            linkedNodes{iNode} = ebrains.kg.downloadInstance(thisNode.x_id);
        end
        resolvedNodes{iNode} = ebrains.kg.kg2om(linkedNodes{iNode}, ...
            "ResolveLinksDepth", options.ResolveLinksDepth, ...
            "Collection", options.Collection);
    end
    try
        resolvedNodes = [resolvedNodes{:}];
    catch
        %keyboard
    end
end

function unresolvedNodes = createUnresolvedNode(node, expectedObject)
    numNodes = numel(node);
    unresolvedNodes = cell(1, numNodes); % todo, init ccorrect type
    for iNode = 1:numNodes
        thisNode = node(iNode);

        if openminds.utility.isMixedInstance( expectedObject )
            unresolvedNodes{iNode} = feval(class(expectedObject), thisNode);
        else
            % % if isa(expectedType, 'openminds.abstract.ControlledTerm')
            % %     % Todo: resolve using kg to OMI controlled instance map
            % % else
            % % end
            unresolvedNodes{iNode} = feval(class(expectedObject), 'id', thisNode.x_id);
        end
    end
    unresolvedNodes = [unresolvedNodes{:}];
end

function tf = isLinkedNode(node)
    tf = isstruct(node) && isfield(node, 'x_id');
end

function tf = isEmbeddedNode(node)
    tf = isstruct(node) && isfield(node, 'x_type');
end

function tf = isControlledInstance(node)
    tf = false;
    %isstruct(node) && isfield()
end