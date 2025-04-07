classdef DatasetCollection < ebrains.kg.KGCollection

    properties
        Identifier (1,1) string
    end

    properties
        LinksToResolve (1,1) double = 1
    end

    properties (SetAccess = private)
        Dataset
    end

    methods
        function obj = DatasetCollection(identifier, options)
            arguments
                identifier
                options.type (1,1) string {mustBeMember(options.type, [ ...
                    "Dataset", ...
                    "DatasetVersion" ] ...
                    )} = "Dataset"
                options.LinksToResolve (1,1) double = 1
            end
            

            obj = obj@ebrains.kg.KGCollection('Space', 'dataset');

            if isfield(options, 'LinksToResolve')
                obj.LinksToResolve = options.LinksToResolve;
            end
            
            obj.Identifier = identifier;
            instance = obj.downloadInstance(options.type, obj.Identifier, "any");

            try
                omInstance = ebrains.kg.internal.convert.fairgraph2openminds(...
                    instance, obj.FairgraphClient, ...
                    ResolveLinksDepth=obj.LinksToResolve);
            catch ME
                omInstance = feval( metadataType.ClassName, 'id', 'none' );
                disp(ME.message)
            end
            obj.Dataset = omInstance;
            obj.add(omInstance);
        end
    end
end
