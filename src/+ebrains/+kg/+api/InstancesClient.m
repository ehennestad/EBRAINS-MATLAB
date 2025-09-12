classdef InstancesClient < handle %KGClient

    methods
        function result = listInstances(obj, type, requiredParams, optionalParams, serverOptions)
        % listInstances - Returns a list of instances according to their types.
        
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                type  (1,1) string
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
                requiredParams.space (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.searchByLabel          string
                optionalParams.filterProperty         string
                optionalParams.filterValue            
                optionalParams.from                   uint64
                optionalParams.size                   uint64
                optionalParams.returnTotalResults     logical
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end
        
            OPERATION = "GET";
            ENDPOINT_PATH = "/instances";
                    
            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            requiredParams.type = ebrains.kg.api.internal.ensureExpandedTypeName(type);
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

            resp = req.send(apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                ebrains.kg.api.internal.throwError("listInstances", resp, serverOptions.Server)
            end
        end

        function result = getInstance(obj, identifier, stage, optionalParams, serverOptions) % Todo: Get instance
        % getInstance - Downloads KG metadata instance for the given identifier.
        %
        % Syntax:
        %   metadataInstance = ebrains.kg.api.downloadInstance(identifier, stage, optionals)
        %   Downloads instance data from the API using the specified identifier,
        %   stage, and optional parameters for additional configurations.
        %
        % Input Arguments:
        %   identifier string      - The unique identifier of the instance to be downloaded.
        %   stage (1,1) string     - The stage of the instance to retrieve; options include
        %                            "IN_PROGRESS", "RELEASED", or "ANY". Defaults to "ANY".
        %   optionals              - Optional structure with the following fields:
        %       returnIncomingLinks logical   - If true, return incoming links; default is false.
        %       incomingLinksPageSize int64   - Number of incoming links to return per page; default is 10.
        %       returnPayload logical         - If true, return the payload; default is true.
        %       returnPermissions logical     - If true, return permissions; default is false.
        %       returnAlternatives logical    - If true, return alternatives; default is false.
        %       returnEmbedded logical        - If true, return embedded data; default is true.
        %
        % Output Arguments:
        %   metadataInstance        - The downloaded metadata instance.
        
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                stage (1,1) string { mustBeMember(stage, ["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            if startsWith(identifier, "https://kg.ebrains.eu/api/instances/")
                 identifier = strrep(identifier, "https://kg.ebrains.eu/api/instances/", "");
            end

            OPERATION = "GET";
            ENDPOINT_PATH = "/instances" + "/" + identifier;
            
            req = obj.initializeRequestMessage(OPERATION);

            if stage == "ANY" % todo: should move to another layer
                stage = ["RELEASED", "IN_PROGRESS"];
            end

            for i = 1:numel(stage)
                requiredParams = struct('stage', stage(i));

                apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
                
                resp = req.send(apiURL);

                if resp.StatusCode == "OK"
                    result = resp.Body.Data.data;
                    break
                else
                    if i == numel(stage)
                        ebrains.kg.api.internal.throwError("getInstance", resp)
                    end
                end
            end
        end

        function result = createNewInstance(obj, payloadJson, requiredParams, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                requiredParams.space                  (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks    logical 
                optionalParams.incomingLinksPageSize  int64 
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "POST";
            ENDPOINT_PATH = "/instances";
            
            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);
            
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
            resp = req.send(apiURL, obj.getOptionsForRawResponse());
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                ebrains.kg.api.internal.throwError("listInstances", resp)
            end
        end
        
        function result = createNewInstanceWithId(obj, identifier, payloadJson, requiredParams, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier (1,1) string
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                requiredParams.space                  (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks    logical 
                optionalParams.incomingLinksPageSize  int64 
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "POST";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);
            
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
            resp = req.send(apiURL, HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                ebrains.kg.api.internal.throwError("listInstances", resp)
            end
        end

        function result = updateInstance(obj, identifier, payloadJson, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "PATCH";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);
            
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);
            resp = req.send(apiURL, HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                ebrains.kg.api.internal.throwError("updateInstance", resp)
            end
        end

        function result = replaceInstance(obj, identifier, payloadJson, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                payloadJson       (1,1) string {mustBeNonzeroLengthText}
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "PUT";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);
            
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);
            resp = req.send(apiURL, HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                ebrains.kg.api.internal.throwError("replaceInstance", resp)
            end
        end

        function result = deleteInstance(obj, identifier, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "DELETE";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, struct.empty);

            resp = req.send(apiURL);

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                ebrains.kg.api.internal.throwError("listInstances", resp)
            end
        end
    end

    methods (Static, Access = protected)
        function req = initializeRequestMessage(operationName, options)
            arguments
                operationName (1,1) string
                options.JSONPayload (1,1) string = missing
            end

            headers = ebrains.kg.api.internal.getStandardHeader();
            req  = matlab.net.http.RequestMessage(char(operationName), headers);

            if ~ismissing(options.JSONPayload)
                % Todo: Add header with content-type json here...
                body = matlab.net.http.MessageBody();
                body.Payload = char(options.JSONPayload);
                req.Body = body;
            end
        end

        function apiURL = buildApiURL(server, endpointPath, requiredParams, optionalParams)
            arguments
                server (1,1) ebrains.kg.enum.KGServer
                endpointPath (1,1) string
                requiredParams = struct.empty
                optionalParams = struct.empty
            end

            serverUrl = ebrains.common.constant.KGCoreApiBaseURL("Server", server);

            if ~isempty(requiredParams) && isempty(fieldnames(requiredParams))
                requiredParams = struct.empty;
            end
            if ~isempty(optionalParams) && isempty(fieldnames(optionalParams))
                optionalParams = struct.empty;
            end

            queryParameters = [...
                matlab.net.QueryParameter(requiredParams), ...
                matlab.net.QueryParameter(optionalParams) ...
                ];
        
            apiURL = matlab.net.URI(serverUrl + endpointPath, queryParameters);
        end
    
        function httpOpts = getOptionsForRawResponse()
            httpOpts = matlab.net.http.HTTPOptions('ConvertResponse', false);
        end
    end
end
