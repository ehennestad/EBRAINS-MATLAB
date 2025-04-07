function omNodes = replaceControlledInstanceIds(omNodes, kg2OmIdentifierMap)

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
