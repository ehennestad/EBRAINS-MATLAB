function map = getIdentifierMapping()

    mapFilepath = fullfile(...
        ebrains.kg.namespacedir(), ...
        'resources', ...
        'kg2om_identifier_loopkup.json');
    
    data = jsondecode(fileread(mapFilepath));

    keys = string({data.kg});

    isEmpty = arrayfun(@(s) isempty(s.om), data);
    [data(isEmpty).om] = '';
    values = string({data.om});
    
    if exist('dictionary', 'file')
        map = dictionary(keys, values);
    else
        map = containers.Map(keys, values);
    end
end
