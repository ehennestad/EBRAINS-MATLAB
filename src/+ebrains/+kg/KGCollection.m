classdef KGCollection < openminds.Collection
    
    % Todo: add method to resolve links...

    properties (Dependent, Access = protected)
        FairgraphClient
    end

    properties (Access = private)
        FairgraphClient_
    end
    
    methods 
        function wasSuccess = downloadRemoteInstances(obj, metadataType, options)
            
            %Todo: how to apply custom property filters based on
            %templates/configs, i.e only get strains for individual species

            arguments
                obj
                metadataType (1,1) openminds.enum.Types
                options.ProgressDialog matlab.ui.dialog.ProgressDialog = matlab.ui.dialog.ProgressDialog.empty
                options.Verbose (1,1) logical = false
                %options.Filter struct
            end

            wasSuccess = false;

            fgClient = obj.FairgraphClient;
            fgInstance = obj.getFairgraphObject(metadataType);

            listedInstances = {};

            if ~isempty(options.ProgressDialog)
                options.ProgressDialog.Message = 'Downloading instances...';
                options.ProgressDialog.Indeterminate = true;
            end

            isFinished = false;
            count = 0;
            while ~isFinished

                result = fgInstance.list(obj.FairgraphClient, size=uint16(100), from_index=uint16(count));

                if isempty( cell(result) )
                    isFinished = true;
                else
                    listedInstances = [listedInstances, cell(result)]; %#ok<AGROW>
                    count = numel(listedInstances);
                end
                disp(count)

                progressMessage = sprintf('Downloading instances... Received %d...', numel(listedInstances) );

                if ~isempty(options.ProgressDialog)
                    options.ProgressDialog.Message = progressMessage;
                elseif options.Verbose
                    disp(progressMessage)
                end
            end

            if ~isempty(options.ProgressDialog)
                options.ProgressDialog.Indeterminate = false;
                options.ProgressDialog.Message = "Processing instances...";
            end

            % convert to openminds
            omInstances = feval(sprintf( '%s.empty', metadataType.ClassName) );
            for i = 1:numel(listedInstances)
                %omInstances(i) = ebrains.kg.internal.convert.fairgraph2openminds(listedInstances{i}, fgClient);

                try
                    omInstances(i) = ebrains.kg.internal.convert.fairgraph2openminds(listedInstances{i}, fgClient);
                catch ME
                    omInstances(i) = feval( metadataType.ClassName, 'id', 'none' );
                    disp(ME.message)
                end
                if ~isempty(options.ProgressDialog)
                    options.ProgressDialog.Value = 1/numel(listedInstances);
                    options.ProgressDialog.Message = sprintf("Processing instances (%d/%d done)...", i, numel(listedInstances));
                end
            end

            ids = {omInstances.id};
            toSkip = strcmp(ids, 'none');
            omInstances(toSkip) = [];
    
            if ~isempty(options.ProgressDialog)
                delete(options.ProgressDialog)
            end

            % Add to collection
            for i = 1:numel(omInstances)
                if ~obj.contains(omInstances(i))
                    obj.add(omInstances(i));
                end
            end
            wasSuccess = true;
        end
    
        function instance = downloadInstance(obj, metadataType, instanceId, scope)
            arguments
                obj (1,1) ebrains.kg.KGCollection
                metadataType (1,1) openminds.enum.Types
                instanceId (1,1) string
                scope (1,1) string {mustBeMember(scope, ["released", "in progress", "any"])} = "any"
            end
            
            fgClient = obj.FairgraphClient;
            fgInstance = obj.getFairgraphObject(metadataType);
           
            instance = fgInstance.from_id(instanceId, fgClient, scope=scope, use_cache=false);
        end

        function downloadTypes(obj)

        end

        function resolve(obj)

        end
    end

    methods
        function fgClient = get.FairgraphClient(comp)
            if isempty(comp.FairgraphClient_)
                comp.initializeFairgraphClient()
            end
            fgClient = comp.FairgraphClient_;
        end
    end

    methods (Access = protected)
        %Add an instance to the Node container.
        function addNode(obj, instance, options)
    
            arguments
                obj (1,1) openminds.Collection
                instance
                options.AddSubNodesOnly = false
                options.AbortIfNodeExists = true;
            end

            if isstruct(instance)
                obj.Nodes(instance.id) = {instance};
            elseif isa(instance, 'openminds.abstract.Schema')
                nvPairs = namedargs2cell(options);
                addNode@openminds.Collection(obj, instance, nvPairs{:});
            end
            
            if isempty(instance.id)
                instance.id = obj.getBlankNodeIdentifier();
            end

            if isConfigured(obj.Nodes)
                if isKey(obj.Nodes, instance.id)
                    %warning('Node with id %s already exists in collection', instance.id)
                    if options.AbortIfNodeExists
                        return
                    end
                end
            end
        end
    end

    methods (Access = private)
        function initializeFairgraphClient(comp)
            % Todo: Get from singleton.
            authClient = ebrains.iam.AuthenticationClient.instance();
            comp.FairgraphClient_ = py.fairgraph.KGClient( authClient.AccessToken, host="core.kg.ebrains.eu" ); 
        end

        function fgInstance = getFairgraphObject(obj, metadataType)
            arguments
                obj (1,1) ebrains.kg.KGCollection
                metadataType (1,1) openminds.enum.Types
            end
            typeClassName = metadataType.ClassName;
            fairgraphType = ebrains.kg.internal.convert.getFairgraphType(typeClassName);
            fgInstance = feval(fairgraphType);
        end
    end 
end