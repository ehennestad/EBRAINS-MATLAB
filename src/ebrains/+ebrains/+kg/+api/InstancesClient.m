classdef InstancesClient < ebrains.kg.api.base.BaseClient

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

            resp = obj.sendRequest(req, apiURL);

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "GET";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION);

            if stage == "ANY"
                stage = ["RELEASED", "IN_PROGRESS"];
            end

            for i = 1:numel(stage)
                requiredParams = struct('stage', stage(i));

                apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

                if responseOptions.RawOutput
                    resp = obj.sendRequest(req, apiURL, obj.getOptionsForRawResponse());
                else
                    resp = obj.sendRequest(req, apiURL);
                end

                % Only a miss in one stage justifies looking in the next one.
                % Any other failure (authorization, server error) applies to
                % every stage and is reported right away.
                isMissingInStage = resp.StatusCode == "NotFound";
                hasMoreStages = i < numel(stage);

                if resp.StatusCode == "OK"
                    if isfield(resp.Body.Data, 'data')
                        result = resp.Body.Data.data;
                    else
                        result = resp.Body.Data;
                    end
                    break
                elseif ~(isMissingInStage && hasMoreStages)
                    obj.throwError("getInstance", resp, serverOptions.Server)
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
            resp = obj.sendRequest(req, apiURL, obj.getOptionsForRawResponse());

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "POST";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
            resp = obj.sendRequest(req, apiURL, obj.getOptionsForRawResponse());

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "PATCH";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);
            resp = obj.sendRequest(req, apiURL, obj.getOptionsForRawResponse());

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "PUT";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", payloadJson);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);
            resp = obj.sendRequest(req, apiURL, obj.getOptionsForRawResponse());

            if resp.StatusCode == "OK"
                result = jsondecode(char(resp.Body.Data));
            else
                obj.throwError("replaceInstance", resp, serverOptions.Server)
            end
        end

        function result = deleteInstance(obj, identifier, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "DELETE";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, struct.empty);

            resp = obj.sendRequest(req, apiURL);

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "PUT";
            ENDPOINT_PATH = "/instances/" + identifier + "/spaces/" + space;

            % Sending a put request without body/payload will display a warning.
            % We are doing this on purpose, so suppress warning temporarily.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));

            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);

            resp = obj.sendRequest(req, apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "PUT";
            ENDPOINT_PATH = "/instances/" + identifier + "/release";

            % Sending a put request without body/payload will display a warning.
            % We are doing this on purpose, so suppress warning temporarily.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));

            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct.empty, optionalParams);
            resp = obj.sendRequest(req, apiURL);

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

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "GET";
            ENDPOINT_PATH = "/instances/" + identifier + "/release/status";

            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, struct.empty);
            resp = obj.sendRequest(req, apiURL);

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("getReleaseStatus", resp, serverOptions.Server)
            end
        end

        function [result, missingIds] = getInstancesBulk(obj, identifiers, stage, optionalParams, serverOptions)
            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifiers (1,:) string
                stage (1,1) string { mustBeMember(stage,["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical %= false
                optionalParams.incomingLinksPageSize int64 %= 10
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            nvPairs = namedargs2cell(optionalParams);

            if isscalar(identifiers)
                result = obj.getInstance(...
                    identifiers, stage, nvPairs{:}, "Server", serverOptions.Server);
                missingIds = string.empty; % getInstance errors when it finds nothing
                return
            end

            [result, missingIds, advice] = obj.fetchInstancesByIds(...
                identifiers, stage, nvPairs{:}, "Server", serverOptions.Server);

            % A caller that asks for the missing ids handles them itself.
            if ~isempty(missingIds) && nargout < 2
                missingIdsConcatenated = strjoin("  " + missingIds, newline);
                warning("EBRAINS:KG_API:InstancesNotFound", ...
                    "Failed to retrieve the following instances:\n%s\n%s\n", ...
                    missingIdsConcatenated, advice)
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

            resp = obj.sendRequest(req, apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("listTypes", resp, serverOptions.Server)
            end
        end

        function result = runDynamicQuery(obj, jsonldPayload, requiredParams, optionalParams, serverOptions)
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

            resp = obj.sendRequest(req, apiURL); % matlab.net.http.HTTPOptions('SavePayload', true, 'ConvertResponse', false));

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("runDynamicQuery", resp, serverOptions.Server)
            end
        end
    end

    methods (Access = private)
        function [result, missingIds, advice] = fetchInstancesByIds(obj, identifiers, stage, optionalParams, serverOptions)
        % fetchInstancesByIds - Request instances by id, trying both stages for "ANY"
        %
        %   Always posts to the bulk endpoint, also for a single id, so that
        %   an id that is missing in one stage can be looked for in the
        %   other without erroring. The advice output says what a caller
        %   can do about the ids that are still missing.

            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifiers (1,:) string
                stage (1,1) string { mustBeMember(stage,["IN_PROGRESS", "RELEASED", "ANY"]) } = "ANY"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "POST";
            ENDPOINT_PATH = "/instancesByIds";

            req = obj.initializeRequestMessage(OPERATION);

            identifiers = ebrains.kg.api.internal.normalizeIdentifiers(identifiers);

            % A scalar string would be encoded as a JSON string, but the
            % endpoint expects a JSON array even for a single identifier.
            req.Body = matlab.net.http.MessageBody(cellstr(identifiers));

            if stage == "ANY"
                stage = ["RELEASED", "IN_PROGRESS"];
            end

            requiredParams = struct('stage', stage(1));
            fullApiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

            response = obj.sendRequest(req, fullApiURL);

            if response.StatusCode ~= "OK"
                obj.throwError("getInstancesBulk", response, serverOptions.Server)
            end

            [result, missingIds] = processBulkResponse(response);
            advice = "";

            if ~isempty(missingIds)
                result(cellfun('isempty', result)) = [];

                if numel(stage) == 2 % Look for the missing ids in the other stage
                    nvPairs = namedargs2cell(optionalParams);
                    [metadataInstancesInProgress, missingIds] = obj.fetchInstancesByIds(...
                        missingIds, "IN_PROGRESS", nvPairs{:}, "Server", serverOptions.Server);
                    result = [result, metadataInstancesInProgress];
                    advice = "They were not found in stage RELEASED or IN_PROGRESS.";
                else
                    otherStage = setdiff(["RELEASED", "IN_PROGRESS"], stage);
                    advice = sprintf("Please try downloading using stage %s instead.", otherStage);
                end
            end

            function [metadataInstances, missingIds] = processBulkResponse(response)
                data = struct2cell(response.Body.Data.data);

                missingIds = string.empty(1, 0);
                numInstances = numel(data);
                metadataInstances = cell(1, numInstances);

                for iInstance = 1:numInstances
                    if ~isempty(data{iInstance}.error)
                        missingIds(end+1) = string(data{iInstance}.error.message); %#ok<AGROW>
                    end
                    metadataInstances{iInstance} = data{iInstance}.data;
                end
            end
        end
    end
end
