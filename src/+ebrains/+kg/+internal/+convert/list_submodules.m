function submodules = list_submodules(package_name)
    
    error('Not working')
    import ebrains.kg.internal.convert.list_submodules

    % Import the package
    package = py.importlib.import_module(package_name);
    
    % Initialize an empty list to hold the submodule names
    submodules = string.empty;

    propNames = properties(package);
    for i = 1:numel(propNames)
        if isa(package.(propNames{i}), 'py.module')
            submodules(end+1) = string(propNames{i});
            subPackageName = string(package_name) + "." + string(propNames{i});
            try
                submodules = [submodules, list_submodules(subPackageName)];
            end
        end
    end
end