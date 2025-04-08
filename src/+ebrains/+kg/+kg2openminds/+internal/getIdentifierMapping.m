function map = getIdentifierMapping(options)

    arguments
        options.Reverse (1,1) logical = false
    end

    mapFilepath = fullfile(...
        ebrains.common.namespacedir('ebrains.kg'), ...
        'resources', ...
        'kg2om_identifier_loopkup.json');
    data = jsondecode(fileread(mapFilepath));

    keys = string({data.kg});
    values = string({data.om});

    if options.Reverse
        if exist('dictionary', 'file')
            map = dictionary(values, keys);
        else
            map = containers.Map(values, keys);
        end
    else
        if exist('dictionary', 'file')
            map = dictionary(keys, values);
        else
            map = containers.Map(keys, values);
        end
    end
end
