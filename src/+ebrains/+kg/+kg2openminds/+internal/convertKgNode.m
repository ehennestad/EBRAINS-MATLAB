function omNode = convertKgNode(kgNode)

    if numel(kgNode) > 1
        omNode = cell(1, numel(kgNode));
        for i = 1:numel(kgNode)
            omNode{i} = ebrains.kg.kg2openminds.internal.convertKgNode(kgNode{i});
        end
        return
    end

    [identifier, type] = ebrains.kg.internal.getNodeKeywords(kgNode, "id", "type");
    
    omNode = ebrains.kg.kg2openminds.internal.filterData(kgNode);
    omNode = ebrains.kg.kg2openminds.internal.removeContextPrefix(omNode);
    
    assert(iscell(type) && numel(type)==1, ...
        "Expected @type to be a cell with one element. If you see this error, please report.")
    omNode.at_type = type{1};
    omNode.at_id = identifier;
end
