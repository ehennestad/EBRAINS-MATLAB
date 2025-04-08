function metadataNode = removeContextPrefix(metadataNode)
% removeContextPrefix - Remove the openminds IRI context prefix from the property names
    arguments
        metadataNode (1,1) struct
    end

    OPENMINDS_IRI = "https___openminds_ebrains_eu_vocab_";

    propertyNames = fieldnames(metadataNode);
    for i = 1:numel(OPENMINDS_IRI)
        propertyNames = strrep(propertyNames, ...
            OPENMINDS_IRI(i), '');
    end

    propertyValues = struct2cell(metadataNode);
    metadataNode = cell2struct(propertyValues, propertyNames);
end
