function omNode = convertKgNode(kgNode)
% convertKgNode - Convert a knowledge graph node to an openMINDS formatted node.
%
% Syntax:
%   omNode = ebrains.kg.kg2openminds.internal.convertKgNode(kgNode)
%
% Input Arguments:
%   kgNode (1,:) - Struct or cell array of metadata nodes/instances returned from the 
%       instances api endpoint.
%
% Output Arguments:
%   omNode - Converted openMINDS node or an array of openMINDS nodes if
%       multiple input kgNode structures are provided.

    arguments
        kgNode (1,:) {mustBeA(kgNode, ["struct", "cell"])} % Metadata node/instance returned from the instances api endpoint
    end

    % Loop through each node if a list is provided
    if numel(kgNode) > 1
        omNode = cell(1, numel(kgNode));
        if ~iscell(kgNode); kgNode = num2cell(kgNode); end
        for i = 1:numel(kgNode)
            omNode{i} = ebrains.kg.kg2openminds.internal.convertKgNode(kgNode{i});
        end
        try
            omNode = [omNode{:}];
        end
        return
    end

    [identifier, type] = ebrains.kg.internal.getNodeKeywords(kgNode, "@id", "@type");
    
    omNode = ebrains.kg.kg2openminds.internal.filterProperties(kgNode);
    omNode = ebrains.kg.kg2openminds.internal.removeContextPrefix(omNode);
    
    propertyNames = fieldnames(omNode);
    for i = 1:numel(propertyNames)
        thisPropertyName = propertyNames{i};
        % Recursively process embedded nodes
        if isstruct(omNode.(thisPropertyName))
            thisPropertyValue = omNode.(thisPropertyName);
            omNode.(thisPropertyName) = ebrains.kg.kg2openminds.internal.convertKgNode(thisPropertyValue);
        end
    end

    if ~isempty(type)
        assert(iscell(type) && numel(type)==1, ...
            "Expected @type to be a cell with one element. If you see this error, please report.")
        omNode.at_type = type{1};
    end
    if ~isempty(identifier)
        omNode.at_id = identifier;
    end
end

