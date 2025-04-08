function metadataNode = filterProperties(metadataNode)
% filterProperties - Remove fields that do not represent openMINDS metadata properties
%
% Syntax:
%   metadataNode = ebrains.kg.kg2openminds.internal.filterProperties(metadataNode)
%   This function filters out fields from a metadata node that are not 
%   relevant to openMINDS metadata properties. For example, a KG metadata
%   not carries extra information that is not part of openMINDS.
%
% Input Arguments: 
%   metadataNode (1,:) struct - The input struct containing metadata fields
%
% Output Arguments: 
%   metadataNode (1,:) struct - The filtered metadata struct with 
%   non-relevant fields removed

    arguments
        metadataNode (1,:) struct
    end

    fieldNames = fieldnames(metadataNode);
    
    doExclude = ...
        startsWith(fieldNames, 'https___core_kg_ebrains') ...
        | startsWith(fieldNames, 'http___schema_org_identifier') ...
        | strcmp(fieldNames, 'x_id') ...
        | strcmp(fieldNames, 'x_type');

    fieldsToRemove = fieldNames(doExclude);
    metadataNode = rmfield(metadataNode, fieldsToRemove);
end
