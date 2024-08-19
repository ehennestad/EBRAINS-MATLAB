function omObject = fairgraph2openminds(fgObject, fgClient, options)

    arguments
        fgObject
        fgClient
        options.ResolveLinksDepth = 0
    end
    
    % NB: Dependency: openminds UI
    
    fgType = class(fgObject);
    
    fgTypeSplit = strsplit(fgType, '.');
    numNamespace = numel(fgTypeSplit);

    omType = fgTypeSplit([3:numNamespace-2, numNamespace]);
    omType = strjoin(omType, '.');
    omType = strrep(omType, '_', '');


    if isprop(fgObject, 'id')
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
            
            elseif isa(fgPropertyValue{j}, 'py.str')
                fgPropertyValue{j} = string(fgPropertyValue{j});
            elseif isa(fgPropertyValue{j}, 'py.fairgraph.base.IRI')
                fgPropertyValue{j} = string(fgPropertyValue{j}.value);

            elseif isa(fgPropertyValue{j}, 'py.fairgraph.kgproxy.KGProxy')
                if options.ResolveLinksDepth > 0
                    fgPropertyValue{j} = fgPropertyValue{j}.resolve();
                    fgPropertyValue{j} = ebrains.kg.internal.convert.fairgraph2openminds(fgPropertyValue{j}, fgClient);
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
                fgPropertyValue{j} = ebrains.kg.internal.convert.fairgraph2openminds(fgPropertyValue{j}, fgClient);
            else
                doSetProperty = false;
                disp(omProperties{i})
            end
        end

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
    end    
end

function pythonName = jsonicName2pythonicName(jsonName, isPlural)
% jsonicName2pythonicName - Convert name    
    import om.internal.vocab.getPropertyAlias
    if nargin < 2; isPlural = false; end
    label = getPropertyAlias(jsonName, 'Alias', 'label', "Plural", isPlural);
    pythonName = strrep(lower(label), ' ', '_');
end