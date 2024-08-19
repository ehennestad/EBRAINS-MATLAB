function python_name = generatePythonName(json_name)
    % Define the mappings
    name_map = containers.Map; % Initialize as empty, add your specific mappings
    number_names = containers.Map({'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}, ...
                                  {'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'});
    
    % Check if the name exists in the map
    if isKey(name_map, json_name)
        python_name = name_map(json_name);
    else
        % Perform the substitutions
        python_name = regexprep(json_name, '(.)([A-Z][a-z]+)', '$1_$2');
        python_name = regexprep(python_name, '([a-z0-9])([A-Z])', '$1_$2');
        python_name = lower(python_name);
        
        % Define replacements
        replacements = {'-', '_'; '.', '_'; '+', 'plus'; '#', 'sharp'; ',', 'comma'; '(', ''; ')', ''};
        for i = 1:size(replacements, 1)
            python_name = strrep(python_name, replacements{i, 1}, replacements{i, 2});
        end
        
        % Check if the name starts with a number
        if isKey(number_names, python_name(1))
            python_name = strcat(number_names(python_name(1)), python_name(2:end));
        end
        
        % Check if the name is a valid identifier
        if ~isvarname(python_name)
            error('NameError:Cannot generate a valid Python name from "%s"', json_name);
        end
    end
end
