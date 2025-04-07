function dataOut = filterData(dataIn)
% filterData - Keep fields that represent metadata properties of a
% metadata instance
    
    fieldNames = fieldnames(dataIn);
    
    doExclude = ...
        startsWith(fieldNames, 'https___core_kg_ebrains') ...
        | startsWith(fieldNames, 'http___schema_org_identifier') ...
        | strcmp(fieldNames, 'x_id') ...
        | strcmp(fieldNames, 'x_type');

    fieldsToRemove = fieldNames(doExclude);
    dataOut = rmfield(dataIn, fieldsToRemove);
end
