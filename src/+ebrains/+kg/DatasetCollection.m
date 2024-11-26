classdef DatasetCollection < ebrains.kg.KGCollection

    properties
        DatasetUUID (1,1) string
    end

    properties
        LinksToResolve (1,1) logical = 1
    end

    properties (SetAccess = private)
        Dataset
    end

    methods
        function obj = DatasetCollection(datasetUUID)
            obj = obj@ebrains.kg.KGCollection();
            obj.DatasetUUID = datasetUUID;

            instance = obj.downloadInstance("DatasetVersion", obj.DatasetUUID, "in progress");

            try
                omInstance = ebrains.kg.internal.convert.fairgraph2openminds(instance, obj.FairgraphClient, ResolveLinksDepth=1);
            catch ME
                omInstance = feval( metadataType.ClassName, 'id', 'none' );
                disp(ME.message)
            end
            obj.Dataset = omInstance;
            obj.add(omInstance);
        end
    end
end