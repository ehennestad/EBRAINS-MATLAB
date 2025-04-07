classdef KGResolver < handle

    properties (Access = private)
        Kg2OmIdentifierMap = ebrains.kg.kg2openminds.internal.getIdentifierMapping()
    end

    methods
        function instance = resolve(obj, identifier, options)
            arguments
                obj, 
                identifier (1,1) string
                options.NumLinksToResolve = 0
            end

            if isKey(obj.Kg2OmIdentifierMap, identifier) % Controlled instance
                openMindsIdentifier = obj.Kg2OmIdentifierMap(identifier);
                instance = openminds.instanceFromIRI(openMindsIdentifier);
            else
                instance = [];
                % Todo: Download from KG
            end
        end
    end
end
