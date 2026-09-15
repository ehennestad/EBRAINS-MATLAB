classdef QueriesClient < ebrains.kg.api.base.BaseClient
    %QueriesClient - Client for the query endpoints of the KG Core API
    %   CLIENT = QueriesClient() creates a client for listing and retrieving
    %   the queries stored in the EBRAINS Knowledge Graph (KG). Requests are
    %   authenticated with the access token held by the EBRAINS token
    %   manager.
    %
    %   Every method accepts Server=SERVER to select the KG server. SERVER
    %   must be:
    %       "prod"    - (default) The production server.
    %       "preprod" - The pre-production server.
    %
    %   QueriesClient functions:
    %       listQueries - List the stored queries
    %       getQuery    - Retrieve one stored query by identifier
    %
    %   See also InstancesClient, ebrains.kg.enum.KGServer

    methods
        function result = listQueries(obj, optionalParams, serverOptions)
        %listQueries - List the stored queries
        %   RESULT = listQueries(OBJ) returns the queries stored in the KG.
        %   RESULT is the data array of the response.
        %
        %   RESULT = listQueries(OBJ,Name=VALUE) also specifies one or more of
        %   the following:
        %       type=TYPE             - Only queries for the type TYPE.
        %       search=TEXT           - Only queries matching TEXT.
        %       from=FROM             - Offset of the first result.
        %       size=SIZE             - Maximum number of results.
        %       returnTotalResults=TF - Whether to include the total count.
        %
        %   RESULT = listQueries(...,Server=SERVER) also specifies the KG server
        %   to send the request to.

            arguments
                obj (1,1) ebrains.kg.api.QueriesClient
                optionalParams.from                   uint64
                optionalParams.size                   uint64
                optionalParams.returnTotalResults     logical
                optionalParams.type                   string
                optionalParams.search                 string
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "GET";
            ENDPOINT_PATH = "/queries";

            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            requiredParams = struct();
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);

            resp = obj.sendRequest(req, apiURL);

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("listQueries", resp, serverOptions.Server)
            end
        end

        function result = getQuery(obj, identifier, serverOptions, responseOptions)
        %getQuery - Retrieve one stored query by identifier
        %   RESULT = getQuery(OBJ,IDENTIFIER) returns the definition of the
        %   stored query IDENTIFIER, a UUID or a full KG instance IRI, as a
        %   decoded struct.
        %
        %   RESULT = getQuery(...,Server=SERVER) also specifies the KG server
        %   to send the request to.
        %
        %   RESULT = getQuery(...,RawOutput=TF) also specifies whether to
        %   return the response body as text, preserving the original JSON-LD
        %   keys, instead of a decoded struct.

            arguments
                obj (1,1) ebrains.kg.api.QueriesClient
                identifier string
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
                responseOptions.RawOutput (1,1) logical = false
            end

            identifier = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

            OPERATION = "GET";
            ENDPOINT_PATH = "/queries" + "/" + identifier;

            req = obj.initializeRequestMessage(OPERATION);

            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, struct, struct);

            if responseOptions.RawOutput
                resp = obj.sendRequest(req, apiURL, obj.getOptionsForRawResponse());
            else
                resp = obj.sendRequest(req, apiURL);
            end

            if resp.StatusCode == "OK"
                if responseOptions.RawOutput
                    result = resp.Body.Data;
                elseif isfield(resp.Body.Data, 'data')
                    result = resp.Body.Data.data;
                else
                    result = resp.Body.Data;
                end
            else
                obj.throwError("getQuery", resp, serverOptions.Server)
            end
        end
    end
end
