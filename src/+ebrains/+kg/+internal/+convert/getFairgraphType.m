function fgType = getFairgraphType(omType)
       
    nameMap = dictionary();
    nameMap("controlledterms") = "controlled_terms";
    nameMap("specimenprep") = "specimen_prep";
    nameMap("digitalidentifier") = "digital_identifier";
    nameMap("digitalidentifier") = "mathematical_shapes";
    nameMap("nonatlas") = "non_atlas";
    

    type = strsplit( omType, '.');

    for i = 1:numel(type)
        if isKey(nameMap, type{i})
            type{i} = char(nameMap(type{i}));
        end
    end

    if numel(type) == 3
        type = strjoin(type, '.');
    elseif numel(type) == 4
        type = strjoin(type([1,2,4]), '.');
    else
        error('Type conversion not handled')
    end

    fgType = sprintf('py.fairgraph.%s', type);
end