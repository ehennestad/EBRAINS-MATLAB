function omObject = fairgraph2openminds(fgObject, fgClient, options)

    arguments
        fgObject
        fgClient
        options.ResolveLinksDepth = 0
        options.Scope = "released"
    end
    
    % NB: Dependency: openminds UI
    if isa(fgObject, 'py.NoneType')
        omObject = []; return
    end

    fgType = class(fgObject);
    
    fgTypeSplit = strsplit(fgType, '.');
    numNamespace = numel(fgTypeSplit);

    omType = fgTypeSplit([3:numNamespace-2, numNamespace]);
    omType = strjoin(omType, '.');
    omType = strrep(omType, '_', '');


    if startsWith( class(fgObject), 'py.fairgraph.openminds.controlled_terms')
        try
            omObject = feval(omType, string(fgObject.name));
            return
        catch ME
            omObject = feval(omType);
        end

    elseif isprop(fgObject, 'id')
        omObject = feval(omType, 'id', fgObject.id);
    else
        omObject = feval(omType);
    end
    
    omProperties = properties(omObject);

    for i = 1:numel(omProperties)
        
        omPropertyName = omProperties{i};
        fgPropertyName = jsonicName2pythonicName(omPropertyName);
        fgPropertyNamePlural = jsonicName2pythonicName(omPropertyName, true);

        doSetProperty = true;

        if isprop(fgObject, fgPropertyNamePlural)
            fgPropertyName = fgPropertyNamePlural;
        end
        
        if ~isprop(fgObject, fgPropertyName)
            fprintf('Did not find property name "%s"\n',  omPropertyName)
            continue
        else
            fgPropertyValue = fgObject.(fgPropertyName);
        end

        if isa(fgPropertyValue, 'py.list')
            fgPropertyValue = cell(fgPropertyValue);
        else
            fgPropertyValue = {fgPropertyValue};
        end

        for j = 1:numel(fgPropertyValue)
            
            if isa(fgPropertyValue{j}, 'py.NoneType')
                doSetProperty = false;
                continue
            elseif isa(fgPropertyValue{j}, 'datetime')
                % pass
            elseif isa(fgPropertyValue{j}, 'py.int')
                fgPropertyValue{j} = double(fgPropertyValue{j});
            elseif isa(fgPropertyValue{j}, 'py.str')
                fgPropertyValue{j} = string(fgPropertyValue{j});
            elseif isa(fgPropertyValue{j}, 'py.fairgraph.base.IRI')
                fgPropertyValue{j} = string(fgPropertyValue{j}.value);

            elseif isa(fgPropertyValue{j}, 'py.fairgraph.kgproxy.KGProxy')
                if options.ResolveLinksDepth > 0
                    try
                        fgPropertyValue{j} = fgPropertyValue{j}.resolve(fgClient, scope="any", use_cache=false);
                    catch ME
                        warning('EBRAINS_MATLAB:FairgraphConvert:CouldNotResolveInstance', ...
                            'Could not resolve instance for property with name "%s".', fgPropertyName)
                        continue
                    end
                    fgPropertyValue{j} = ebrains.kg.internal.convert.fairgraph2openminds(fgPropertyValue{j}, fgClient, "ResolveLinksDepth", options.ResolveLinksDepth-1);
                else

                    if isa( omObject.(omPropertyName), 'openminds.internal.abstract.LinkedCategory')
                        fgPropertyValue{j} = struct('at_id', char(fgPropertyValue{j}.id) );
                        % Todo: Resolve controlled term instances...
                    else
                        fgPropertyType = string( fgPropertyValue{j}.type );
                        omPropertyType = openminds.internal.utility.string.type2class(fgPropertyType);

                        if contains(omPropertyType, 'controlledterms')
                            fgPropertyValue{j} = fgPropertyValue{j}.resolve(fgClient);
                            try
                                fgPropertyValue{j} = feval(omPropertyType, string(fgPropertyValue{j}.name));
                            catch ME
                                disp(ME.message)
                                doSetProperty = false;
                            end
                        else
                            fgPropertyValue{j} = feval(omPropertyType, 'id', fgPropertyValue{j}.id);
                        end
                    end
                end

            elseif isa(fgPropertyValue{j}, 'py.fairgraph.embedded.EmbeddedMetadata')
                fgPropertyValue{j} = ebrains.kg.internal.convert.fairgraph2openminds(fgPropertyValue{j}, fgClient, "ResolveLinksDepth", options.ResolveLinksDepth-1);
            else
                doSetProperty = false;
                disp(omProperties{i})
            end
        end

        try
            if doSetProperty
                if numel(fgPropertyValue) == 1
                    omObject.(omPropertyName) = fgPropertyValue{1};
                else
                    try
                        omObject.(omPropertyName) = [fgPropertyValue{:}];
                    catch
                        omObject.(omPropertyName) = fgPropertyValue;
                    end
                end
            end
        catch ME
            warning('openMINDS:Collection:CouldNotSetProperty', '%s', ME.message)
        end
    end    
end

function pythonName = jsonicName2pythonicName(jsonName, isPlural)
% jsonicName2pythonicName - Convert name    
    import openminds.internal.vocab.getPropertyAlias
    if nargin < 2; isPlural = false; end
    label = getPropertyAlias(jsonName, 'Alias', 'label', "Plural", isPlural);
    pythonName = strrep(lower(label), ' ', '_');
end