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
                obj.throwError("listInstances", resp, serverOptions.Server)
            end
        end

        function result = getInstance(obj, identifier, stage, optionalParams, serverOptions, responseOptions)
        % getInstance - Downloads KG metadata instance for the given identifier.
        %
        % Syntax:
        %   metadataInstance = client.getInstance(identifier, stage, optionals)
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
                responseOptions.RawOutput (1,1) logical = false 
            end

            identifier = normalizeIdentifiers(identifier);

            OPERATION = "GET";
            ENDPOINT_PATH = "/instances" + "/" + identifier;
            
            req = obj.initializeRequestMessage(OPERATION);

            if stage == "ANY" % todo: should move to another layer
                stage = ["RELEASED", "IN_PROGRESS"];
            end

            for i = 1:numel(stage)
                requiredParams = struct('stage', stage(i));

                apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
                
                if responseOptions.RawOutput
                    resp = req.send(apiURL, obj.getOptionsForRawResponse());
                else
                    resp = req.send(apiURL);
                end

                if resp.StatusCode == "OK"
                    if isfield(resp.Body.Data, 'data')
                        result = resp.Body.Data.data;
                    else
                        result = resp.Body.Data;
                    end
                    break
                else
                    if i == numel(stage)
                        obj.throwError("getInstance", resp, serverOptions.Server)
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
                obj.throwError("createNewInstance", resp, serverOptions.Server)
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
            resp = req.send(apiURL, obj.getOptionsForRawResponse());
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                obj.throwError("createNewInstanceWithId", resp, serverOptions.Server)
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
            resp = req.send(apiURL, obj.getOptionsForRawResponse());
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                obj.throwError("updateInstance", resp, serverOptions.Server)
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
            resp = req.send(apiURL, obj.getOptionsForRawResponse());
        
            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                obj.throwError("replaceInstance", resp, serverOptions.Server)
            end
        end

        function result = deleteInstance(obj, identifier, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string % Todo: must be uuid or strip KG prefix
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "DELETE";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, struct.empty);

            resp = req.send(apiURL);

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
                if ~nargout; clear result; end
            else
                obj.throwError("deleteInstance", resp, serverOptions.Server)
            end
        end
    
        function result = moveInstance(obj, identifier, space, optionalParams, serverOptions)
        
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier  (1,1) string
                space (1,1) string {mustBeNonzeroLengthText}
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end
        
            OPERATION = "PUT";
            ENDPOINT_PATH = "/instances/" + identifier + "/spaces/" + space;
            
            % Sending a put request without body/payload will display a warning. 
            % We are doing this on purpose, so suppress warning temporarily.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));
            
            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);

            resp = req.send(apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("moveInstance", resp, serverOptions.Server)
            end
        end

        function result = releaseInstance(obj, identifier, optionalParams, serverOptions)
        
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                optionalParams.revision string
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            identifier = normalizeIdentifiers(identifier);

            OPERATION = "PUT";
            ENDPOINT_PATH = "/instances/" + identifier + "/release";

            % Sending a put request without body/payload will display a warning. 
            % We are doing this on purpose, so suppress warning temporarily.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));
            
            req = obj.initializeRequestMessage(OPERATION);
            
            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);
            resp = req.send(apiURL);
        
            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("releaseInstance", resp, serverOptions.Server)
            end
        end

        function result = getReleaseStatus(obj, identifier, requiredParams, serverOptions)
        
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                requiredParams.releaseTreeScope ebrains.kg.enum.ReleaseTreeScope = "TOP_INSTANCE_ONLY"
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            identifier = normalizeIdentifiers(identifier);

            OPERATION = "GET";
            ENDPOINT_PATH = "/instances/" + identifier + "/release/status";
            
            req = obj.initializeRequestMessage(OPERATION);
            
            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, struct.empty);
            resp = req.send(apiURL);
        
            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("getReleaseStatus", resp, serverOptions.Server)
            end
        end

        function result = getInstancesBulk(obj, identifiers, stage, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifiers (1,:) string
                stage (1,1) string { mustBeMember(stage,["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical %= false
                optionalParams.incomingLinksPageSize int64 %= 10
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            if isscalar(identifiers)
                nvPairs = namedargs2cell(optionalParams);
                result = obj.getInstance(...
                    identifiers, stage, nvPairs{:}, "Server", serverOptions.Server);
                return
            end

            OPERATION = "POST";
            ENDPOINT_PATH = "/instancesByIds";

            req = obj.initializeRequestMessage(OPERATION);
            
            identifiers = normalizeIdentifiers(identifiers);
            req.Body = matlab.net.http.MessageBody(identifiers);

            if stage == "ANY"
                stage = ["RELEASED", "IN_PROGRESS"];
            end
        
            requiredParams = struct('stage', stage(1));
            fullApiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

            response = req.send(fullApiURL);
        
            if response.StatusCode == "OK"
                [result, missingIds] = processBulkResponse(response);
                if ~isempty(missingIds)
                    result(cellfun('isempty', result)) = [];
        
                    if numel(stage) == 2 % Call other stage
                        nvPairs = namedargs2cell(optionalParams);
                        metadataInstancesInProgress = obj.getInstancesBulk(missingIds, ...
                            "IN_PROGRESS", nvPairs{:}, "Server", serverOptions.Server);
                        result = [result, metadataInstancesInProgress]; 
                    else
                        missingIdsConcatenated = strjoin("  " + string(missingIds), newline);
                        otherStage = setdiff(["RELEASED", "IN_PROGRESS"], stage);
                        warning(['Failed to retrieve the following instances:\n%s\n', ...
                            'Please try downloading using stage %s instead\n'], missingIdsConcatenated, otherStage)
                    end
                end
            else
                obj.throwError("getInstancesBulk", response, serverOptions.Server)
            end

            function [metadataInstances, missingIds] = processBulkResponse(response)
                data = struct2cell(response.Body.Data.data);
            
                missingIds = string.empty;
                numInstances = numel(data);
                metadataInstances = cell(1, numInstances);
                
                for iInstance = 1:numInstances
                    if ~isempty(data{iInstance}.error)
                        missingIds(end+1)=string(data{iInstance}.error.message); %#ok<AGROW>
                    end
                    metadataInstances{iInstance} = data{iInstance}.data;
                end
            end
        end
    
        function result = listTypes(obj, requiredParams, optionalParams, serverOptions)
            
           arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "IN_PROGRESS"
                optionalParams.space (1,1) string {mustBeNonzeroLengthText} = "dataset"
                optionalParams.withProperties         logical
                optionalParams.withIncomingLinks      logical
                optionalParams.from                   uint64
                optionalParams.size                   uint64
                optionalParams.returnTotalResults     logical
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end
            
            OPERATION = "GET";
            ENDPOINT_PATH = "/types";
                    
            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

            resp = req.send(apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("listTypes", resp, serverOptions.Server)
            end
        end
    
        function runDynamicQuery(obj, jsonldPayload, requiredParams, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                jsonldPayload (1,1) string
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "IN_PROGRESS"
                optionalParams.from int64
                optionalParams.size int64
                optionalParams.returnTotalResults logical
                optionalParams.instanceId string
                optionalParams.restrictToSpaces string
                optionalParams.allRequestParams string % ??
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "POST";
            ENDPOINT_PATH = "/queries";

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", jsonldPayload);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

            resp = req.send(apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));
        
            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("runDynamicQuery", resp, serverOptions.Server)
            end
        end
    end

    methods (Static, Access = protected)
        function req = initializeRequestMessage(operationName, options)
            arguments
                operationName (1,1) string
                options.JSONPayload (1,1) string = missing
            end

            headers = ebrains.kg.api.InstancesClient.getDefaultHeader();
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
    
        function headers = getDefaultHeader()
            tokenManager = ebrains.getTokenManager();
        
            headers = [ ...
                matlab.net.http.HeaderField("Content-Type", "application/json"), ...
                matlab.net.http.HeaderField("Accept", "application/json") ...
                matlab.net.http.field.AuthorizationField("Authorization", "Bearer " + tokenManager.AccessToken) ...
                ];
        end

        function httpOpts = getOptionsForRawResponse()
            httpOpts = matlab.net.http.HTTPOptions('ConvertResponse', false);
        end
    
        function throwError(operationName, responseObject, server)
            arguments
                operationName (1,1) string
                responseObject
                server (1,1) ebrains.kg.enum.KGServer
            end
        
            errorID = sprintf('EBRAINS:KG_API:%s:%s', operationName, responseObject.StatusCode);
        
            errorDescription = '';

            if responseObject.StatusCode == 500
                errorDescription = sprintf('Something went wrong. Please verify that the KG server (%s) is working.', server.Name);
            else
                if isfield(responseObject, 'Body')
                    if isfield(responseObject.Body, 'Data') && ~isempty(responseObject.Body.Data)
                        errorDescription = responseObject.Body.Data;
                    end
                end
            end

            if isempty(errorDescription)
                errorMessage = char(responseObject.StatusCode);
            else
                errorMessage = sprintf('%s: %s', char(responseObject.StatusCode), errorDescription);
            end
        
            ME = MException(errorID, errorMessage);
            throwAsCaller(ME)
        end
    end
end

function identifiers = normalizeIdentifiers(identifiers)
    iriPrefix = ebrains.common.constant.KgInstanceIRIPrefix + "/";
    for i = 1:numel(identifiers)
        if startsWith(identifiers(i), iriPrefix)
             identifiers(i) = strrep(identifiers(i), iriPrefix, "");
        end
    end
end
