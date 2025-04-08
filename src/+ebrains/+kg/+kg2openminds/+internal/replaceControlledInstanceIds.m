function omNodes = replaceControlledInstanceIds(omNodes, kg2OmIdentifierMap)
% replaceControlledInstanceIds - Replace controlled instance IDs in nodes
%
% Syntax:
%   omNodes = replaceControlledInstanceIds(omNodes, kg2OmIdentifierMap) 
%   Replace the controlled instance IDs of the specified nodes using a 
%   mapping from a key-value identifier map. If a KG IRI / @id has a
%   corresponding openMINDS identifier, the KG IRI is replaced by the
%   openMINDS IRI to enable resolving metadata instances from a local
%   openMINDS instance library
%
% Input Arguments:
%   omNodes (1,:) {mustBeA(omNodes, ["struct", "cell"])} - Array of nodes
%   kg2OmIdentifierMap - Map containing the mapping of original IDs to new IDs.
%
% Output Arguments:
%   omNodes - The updated array of nodes with replaced instance IDs.

    arguments
        omNodes (1,:) {mustBeA(omNodes, ["struct", "cell"])}
        kg2OmIdentifierMap
    end

    if ~iscell(omNodes)
        omNodes = num2cell(omNodes);
    end

    for i = 1:numel(omNodes)
        thisNode = omNodes{i};

        nodeProperties = fieldnames(thisNode);
        for j = 1:numel(nodeProperties)
            thisPropertyValue = thisNode.(nodeProperties{j});
            if isstruct(thisPropertyValue)
                if isfield(thisPropertyValue, 'at_id')
                    for k = 1:numel(thisPropertyValue)
                        if isKey(kg2OmIdentifierMap, thisPropertyValue(k).at_id)
                            thisPropertyValue(k).at_id = kg2OmIdentifierMap(thisPropertyValue(k).at_id);
                        end
                        thisNode.(nodeProperties{j}) = thisPropertyValue;
                    end
                else
                    thisNode.(nodeProperties{j}) = ebrains.kg.kg2openminds.internal.replaceControlledInstanceIds(thisPropertyValue, kg2OmIdentifierMap);
                end
            end
        end
        omNodes{i} = thisNode;
    end
    try
        omNodes = [omNodes{:}];
    end
end
