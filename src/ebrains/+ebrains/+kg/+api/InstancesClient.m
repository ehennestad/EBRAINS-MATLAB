classdef InstancesClient < ebrains.kg.api.base.BaseClient
    %InstancesClient - Client for the instance endpoints of the KG Core API
    %   CLIENT = InstancesClient() creates a client for listing, retrieving,
    %   creating, updating, releasing and deleting metadata instances in the
    %   EBRAINS Knowledge Graph (KG). Requests are authenticated with the
    %   access token held by the EBRAINS token manager.
    %
    %   Every method accepts Server=SERVER to select the KG server. SERVER
    %   must be:
    %       "prod"    - (default) The production server.
    %       "preprod" - The pre-production server.
    %
    %   Methods that return instance data also accept the return options
    %   returnPayload=TF, returnPermissions=TF, returnAlternatives=TF and
    %   returnEmbedded=TF. These control which parts of an instance the
    %   server includes in the response.
    %
    %   Instance identifiers may be given as a bare UUID or as a full KG
    %   instance IRI. The IRI prefix is stripped before the request is sent.
    %
    %   InstancesClient functions:
    %       listInstances           - List instances of a given type
    %       getInstance             - Retrieve one instance by identifier
    %       getInstancesBulk        - Retrieve several instances by identifier
    %       createNewInstance       - Create an instance with a generated id
    %       createNewInstanceWithId - Create an instance with a given id
    %       updateInstance          - Partially update an instance
    %       replaceInstance         - Replace the contents of an instance
    %       deleteInstance          - Delete an instance
    %       moveInstance            - Move an instance to another space
    %       releaseInstance         - Release an instance
    %       getReleaseStatus        - Get the release status of an instance
    %       listTypes               - List the types available in a space
    %       runDynamicQuery         - Run a query given as a JSON-LD payload
    %
    %   See also QueriesClient, ebrains.kg.enum.KGServer,
    %   ebrains.kg.enum.KGStage, ebrains.kg.query.ReturnOptions

    methods
        function result = listInstances(obj, type, requiredParams, optionalParams, serverOptions)
        %listInstances - List instances of a given type
        %   RESULT = listInstances(OBJ,TYPE) returns the released instances of
        %   type TYPE in the "dataset" space. TYPE is an openMINDS type given
        %   as a full IRI, or as a short name when openMINDS_MATLAB is on the
        %   path. RESULT is the data array of the response.
        %
        %   RESULT = listInstances(OBJ,TYPE,stage=STAGE) also specifies the
        %   stage to list from. STAGE must be:
        %       "RELEASED"    - (default) Released instances.
        %       "IN_PROGRESS" - Instances that are still in progress.
        %
        %   RESULT = listInstances(OBJ,TYPE,space=SPACE) also specifies the KG
        %   space to list from. The default is "dataset".
        %
        %   RESULT = listInstances(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       searchByLabel=LABEL   - Only instances whose label matches
        %                               LABEL.
        %       filterProperty=PROP   - Property to filter instances on.
        %       filterValue=VALUE     - Value that PROP must have.
        %       from=FROM             - Offset of the first result.
        %       size=SIZE             - Maximum number of results.
        %       returnTotalResults=TF - Whether to include the total count.
        %
        %   RESULT = listInstances(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %getInstance - Retrieve one instance by identifier
        %   RESULT = getInstance(OBJ,IDENTIFIER) returns the released instance
        %   with the given IDENTIFIER, a UUID or a full KG instance IRI.
        %
        %   RESULT = getInstance(OBJ,IDENTIFIER,STAGE) also specifies the
        %   stages to look in, in order of preference. The first stage that
        %   holds the instance wins. STAGE is a vector of one or more of:
        %       "RELEASED"    - (default) The released instance.
        %       "IN_PROGRESS" - The instance that is still in progress.
        %   Pass ["RELEASED","IN_PROGRESS"] to fall back to the draft of an
        %   instance that has not been released.
        %
        %   RESULT = getInstance(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   RESULT = getInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.
        %
        %   RESULT = getInstance(...,RawOutput=TF) also specifies whether to
        %   return the response body as text instead of decoded data.

            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifier string
                stage (1,:) ebrains.kg.enum.KGStage {mustBeNonempty} = "RELEASED"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
                responseOptions.RawOutput (1,1) logical = false
            end

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);
            stage = removeDuplicateStages(stage);

            OPERATION = "GET";
            ENDPOINT_PATH = "/instances" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION);

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
        %createNewInstance - Create an instance with a generated id
        %   RESULT = createNewInstance(OBJ,payloadJson) creates an instance
        %   from the JSON-LD document payloadJson in the "dataset" space and
        %   returns the decoded response body.
        %
        %   RESULT = createNewInstance(OBJ,payloadJson,space=SPACE) also
        %   specifies the KG space to create the instance in.
        %
        %   RESULT = createNewInstance(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   RESULT = createNewInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %createNewInstanceWithId - Create an instance with a given id
        %   RESULT = createNewInstanceWithId(OBJ,IDENTIFIER,payloadJson)
        %   creates an instance with the UUID or full KG instance IRI
        %   IDENTIFIER from the JSON-LD document payloadJson in the "dataset"
        %   space and returns the decoded response body.
        %
        %   RESULT = createNewInstanceWithId(...,space=SPACE) also specifies
        %   the KG space to create the instance in.
        %
        %   RESULT = createNewInstanceWithId(...,Name=VALUE) also specifies
        %   the return options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   RESULT = createNewInstanceWithId(...,Server=SERVER) also specifies
        %   the KG server to send the request to.

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
        %updateInstance - Partially update an instance
        %   RESULT = updateInstance(OBJ,IDENTIFIER,payloadJson) updates the
        %   properties given in the JSON-LD document payloadJson on the
        %   instance IDENTIFIER, a UUID or a full KG instance IRI. Properties
        %   not in the document are left as they are. RESULT is the decoded
        %   response body.
        %
        %   RESULT = updateInstance(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   RESULT = updateInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %replaceInstance - Replace the contents of an instance
        %   RESULT = replaceInstance(OBJ,IDENTIFIER,payloadJson) replaces the
        %   contents of the instance IDENTIFIER, a UUID or a full KG instance
        %   IRI, by the JSON-LD document payloadJson and returns the decoded
        %   response body.
        %
        %   RESULT = replaceInstance(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   RESULT = replaceInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %deleteInstance - Delete an instance
        %   deleteInstance(OBJ,IDENTIFIER) deletes the instance IDENTIFIER, a
        %   UUID or a full KG instance IRI.
        %
        %   RESULT = deleteInstance(OBJ,IDENTIFIER) also returns the data of
        %   the response.
        %
        %   [...] = deleteInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %moveInstance - Move an instance to another space
        %   RESULT = moveInstance(OBJ,IDENTIFIER,SPACE) moves the instance
        %   IDENTIFIER, a UUID or a full KG instance IRI, to the KG space SPACE
        %   and returns the data of the response.
        %
        %   RESULT = moveInstance(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   RESULT = moveInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %releaseInstance - Release an instance
        %   RESULT = releaseInstance(OBJ,IDENTIFIER) releases the instance
        %   IDENTIFIER, a UUID or a full KG instance IRI, and returns the data
        %   of the response.
        %
        %   RESULT = releaseInstance(...,revision=REVISION) also specifies the
        %   revision of the instance to release.
        %
        %   RESULT = releaseInstance(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %getReleaseStatus - Get the release status of an instance
        %   RESULT = getReleaseStatus(OBJ,IDENTIFIER) returns the release
        %   status of the instance IDENTIFIER, a UUID or a full KG instance
        %   IRI.
        %
        %   RESULT = getReleaseStatus(...,releaseTreeScope=SCOPE) also
        %   specifies which instances the status covers. SCOPE must be:
        %       "TOP_INSTANCE_ONLY"        - (default) The instance itself.
        %       "CHILDREN_ONLY"            - The linked child instances.
        %       "CHILDREN_ONLY_RESTRICTED" - The linked child instances, with
        %                                    the restricted scope of the KG.
        %
        %   RESULT = getReleaseStatus(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

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
        %getInstancesBulk - Retrieve several instances by identifier
        %   RESULT = getInstancesBulk(OBJ,IDENTIFIERS) returns the released
        %   instances with the given IDENTIFIERS, a string array of UUIDs or
        %   full KG instance IRIs. RESULT is a cell array of the instances
        %   found, and a warning lists the identifiers that were not found.
        %   When IDENTIFIERS is scalar, RESULT is the instance itself and a
        %   missing instance is an error.
        %
        %   RESULT = getInstancesBulk(OBJ,IDENTIFIERS,STAGE) also specifies
        %   the stages to look in, in order of preference. Identifiers not
        %   found in one stage are looked up in the next. STAGE is a vector of
        %   one or more of:
        %       "RELEASED"    - (default) Released instances.
        %       "IN_PROGRESS" - Instances that are still in progress.
        %
        %   [RESULT,missingIds] = getInstancesBulk(...) also returns the
        %   identifiers that were not found in any of the stages. No warning
        %   is issued in this case.
        %
        %   [...] = getInstancesBulk(...,Name=VALUE) also specifies the return
        %   options and one or more of the following:
        %       returnIncomingLinks=TF     - Whether to include incoming links.
        %       incomingLinksPageSize=SIZE - Number of incoming links per page.
        %
        %   [...] = getInstancesBulk(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifiers (1,:) string
                stage (1,:) ebrains.kg.enum.KGStage {mustBeNonempty} = "RELEASED"
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
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
        %listTypes - List the types available in a space
        %   RESULT = listTypes(OBJ) returns the types that have released
        %   instances in the "dataset" space.
        %
        %   RESULT = listTypes(OBJ,stage=STAGE) also specifies the stage to
        %   list types from. STAGE must be:
        %       "RELEASED"    - (default) Released instances.
        %       "IN_PROGRESS" - Instances that are still in progress.
        %
        %   RESULT = listTypes(OBJ,space=SPACE) also specifies the KG space to
        %   list types from. The default is "dataset".
        %
        %   RESULT = listTypes(...,Name=VALUE) also specifies one or more of
        %   the following:
        %       withProperties=TF     - Whether to include the properties of
        %                               each type.
        %       withIncomingLinks=TF  - Whether to include incoming links.
        %       from=FROM             - Offset of the first result.
        %       size=SIZE             - Maximum number of results.
        %       returnTotalResults=TF - Whether to include the total count.
        %
        %   RESULT = listTypes(...,Server=SERVER) also specifies the KG server
        %   to send the request to.

           arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
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
        %runDynamicQuery - Run a query given as a JSON-LD payload
        %   RESULT = runDynamicQuery(OBJ,jsonldPayload) runs the KG query
        %   specification jsonldPayload against the released stage and
        %   returns the data array of the response.
        %
        %   RESULT = runDynamicQuery(OBJ,jsonldPayload,stage=STAGE) also
        %   specifies the stage to query. STAGE must be:
        %       "RELEASED"    - (default) Released instances.
        %       "IN_PROGRESS" - Instances that are still in progress.
        %
        %   RESULT = runDynamicQuery(...,Name=VALUE) also specifies one or more
        %   of the following:
        %       from=FROM                - Offset of the first result.
        %       size=SIZE                - Maximum number of results.
        %       returnTotalResults=TF    - Whether to include the total count.
        %       instanceId=ID            - Restrict the query to one instance.
        %       restrictToSpaces=SPACES  - Restrict the query to these spaces.
        %
        %   RESULT = runDynamicQuery(...,Server=SERVER) also specifies the KG
        %   server to send the request to.

            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                jsonldPayload (1,1) string
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
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
        %fetchInstancesByIds - Request instances by id from each stage in turn

            arguments
                obj (1,1) ebrains.kg.api.InstancesClient
                identifiers (1,:) string
                stage (1,:) ebrains.kg.enum.KGStage {mustBeNonempty}
                optionalParams.?ebrains.kg.query.ReturnOptions
                optionalParams.returnIncomingLinks logical
                optionalParams.incomingLinksPageSize int64
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            % Post to the bulk endpoint for the first stage, then look for
            % the ids that were not found in the next stage, and so on. Ids
            % missing from every stage are returned, together with advice on
            % what a caller can do about them.
            stage = removeDuplicateStages(stage);
            missingIds = ebrains.kg.api.internal.normalizeIdentifiers(identifiers);
            result = cell(1, 0);

            for iStage = 1:numel(stage)
                [found, missingIds] = obj.requestInstancesByIds(...
                    missingIds, stage(iStage), optionalParams, serverOptions.Server);
                result = [result, found]; %#ok<AGROW> One append per stage
                if isempty(missingIds)
                    break
                end
            end

            if isempty(missingIds)
                advice = "";
            else
                advice = getAdviceForMissingIds(stage);
            end
        end

        function [found, missingIds] = requestInstancesByIds(obj, identifiers, stage, optionalParams, server)
        %requestInstancesByIds - One bulk request against a single stage

            OPERATION = "POST";
            ENDPOINT_PATH = "/instancesByIds";

            req = obj.initializeRequestMessage(OPERATION);

            % A scalar string would be encoded as a JSON string, but the
            % endpoint expects a JSON array even for a single identifier.
            req.Body = matlab.net.http.MessageBody(cellstr(identifiers));

            requiredParams = struct('stage', stage);
            fullApiURL = obj.buildApiURL(server, ENDPOINT_PATH, requiredParams, optionalParams);

            response = obj.sendRequest(req, fullApiURL);

            if response.StatusCode ~= "OK"
                obj.throwError("getInstancesBulk", response, server)
            end

            % The response holds one entry per requested id, with either
            % data or an error whose message names the id.
            entries = reshape(struct2cell(response.Body.Data.data), 1, []);
            hasError = cellfun(@(entry) ~isempty(entry.error), entries);

            found = cellfun(@(entry) entry.data, entries(~hasError), 'UniformOutput', false);
            missingIds = string(cellfun(@(entry) entry.error.message, entries(hasError), 'UniformOutput', false));
        end
    end
end

function stages = removeDuplicateStages(stages)
% removeDuplicateStages - Keep the first occurrence of each stage
%
%   unique does not support enumerations, so the duplicates are found
%   by hand. A duplicate would only repeat a request that already missed.

    keep = true(size(stages));
    for i = 2:numel(stages)
        keep(i) = ~ismember(stages(i), stages(1:i-1));
    end
    stages = stages(keep);
end

function advice = getAdviceForMissingIds(searchedStages)
% getAdviceForMissingIds - Tell the caller which stages are left to try

    allStages = enumeration("ebrains.kg.enum.KGStage");
    otherStages = allStages(~ismember(allStages, searchedStages));

    searched = strjoin(string(searchedStages), " or ");
    if isempty(otherStages)
        advice = sprintf("They were not found in stage %s.", searched);
    else
        advice = sprintf("They were not found in stage %s. Please try stage %s instead.", ...
            searched, strjoin(string(otherStages), " or "));
    end
end
