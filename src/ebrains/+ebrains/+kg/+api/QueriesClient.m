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
%       listQueries     - List the stored queries
%       getQuery        - Retrieve one stored query by identifier
%       runQueryById    - Run a stored query and return the instances it matches
%       runDynamicQuery - Run a query given as a JSON-LD payload
%
%   Query identifiers may be given as a bare UUID or as a full KG instance
%   IRI. The IRI prefix is stripped before the request is sent.
%
%   See also InstancesClient, ebrains.kg.enum.KGServer,
%   ebrains.kg.enum.KGStage

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
                identifier (1,1) string
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

        function result = runDynamicQuery(obj, jsonldPayload, requiredParams, ...
                optionalParams, repeatedParams, filterOptions, serverOptions)
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
        %   RESULT = runDynamicQuery(...,QueryParameters=PARAMS) also
        %   specifies values for the query's own filter parameters. PARAMS is
        %   a struct whose field names are the parameter names declared by
        %   filters in the query specification.
        %
        %   RESULT = runDynamicQuery(...,Server=SERVER) also specifies the KG
        %   server to send the request to.
        %
        %   See also runQueryById

            arguments
                obj (1,1) ebrains.kg.api.QueriesClient
                jsonldPayload (1,1) string
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
                optionalParams.from int64
                optionalParams.size int64
                optionalParams.returnTotalResults logical
                optionalParams.instanceId string
                repeatedParams.restrictToSpaces (1,:) string
                filterOptions.QueryParameters (1,1) struct = struct()
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
            end

            OPERATION = "POST";
            ENDPOINT_PATH = "/queries";

            req = obj.initializeRequestMessage(OPERATION, "JSONPayload", jsonldPayload);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
            apiURL = appendRestrictToSpaces(apiURL, repeatedParams);
            apiURL = appendFilterParameters(apiURL, filterOptions.QueryParameters);

            resp = obj.sendRequest(req, apiURL);

            if resp.StatusCode == "OK"
                result = resp.Body.Data.data;
            else
                obj.throwError("runDynamicQuery", resp, serverOptions.Server)
            end
        end

        function result = runQueryById(obj, queryId, requiredParams, ...
                optionalParams, repeatedParams, filterOptions, serverOptions, ...
                responseOptions)
        %runQueryById - Run a stored query and return the instances it matches
        %   RESULT = runQueryById(OBJ,QUERYID) runs the stored query QUERYID, a
        %   UUID or a full KG instance IRI, against the released stage and
        %   returns the data array of the response.
        %
        %   RESULT = runQueryById(OBJ,QUERYID,stage=STAGE) also specifies the
        %   stage to query. STAGE must be:
        %       "RELEASED"    - (default) Released instances.
        %       "IN_PROGRESS" - Instances that are still in progress.
        %
        %   RESULT = runQueryById(...,Name=VALUE) also specifies one or more of
        %   the following:
        %       from=FROM                - Offset of the first result.
        %       size=SIZE                - Maximum number of results.
        %       returnTotalResults=TF    - Whether to include the total count.
        %       instanceId=ID            - Restrict the query to one instance.
        %       restrictToSpaces=SPACES  - Restrict the query to these spaces.
        %
        %
        %   RESULT = runQueryById(...,QueryParameters=PARAMS) also
        %   specifies values for the query's own filter parameters. PARAMS is
        %   a struct whose field names are the parameter names declared by
        %   filters in the query specification.
        %
        %   RESULT = runQueryById(...,Server=SERVER) also specifies the KG
        %   server to send the request to.
        %
        %   RESULT = runQueryById(...,RawOutput=TF) also specifies whether to
        %   return the response body as text, preserving the original JSON-LD
        %   keys, instead of a decoded struct. A stored query names its own
        %   result properties, so the decoded field names are not under the
        %   caller's control.
        %
        %   See also getQuery, runDynamicQuery

            arguments
                obj (1,1) ebrains.kg.api.QueriesClient
                queryId (1,1) string {mustBeNonzeroLengthText}
                requiredParams.stage (1,1) ebrains.kg.enum.KGStage = "RELEASED"
                optionalParams.from int64
                optionalParams.size int64
                optionalParams.returnTotalResults logical
                optionalParams.instanceId string
                repeatedParams.restrictToSpaces (1,:) string
                filterOptions.QueryParameters (1,1) struct = struct()
                serverOptions.Server (1,1) ebrains.kg.enum.KGServer = "prod"
                responseOptions.RawOutput (1,1) logical = false
            end

            queryId = ebrains.kg.api.internal.normalizeIdentifiers(queryId);

            OPERATION = "GET";
            ENDPOINT_PATH = "/queries/" + queryId + "/instances";

            req = obj.initializeRequestMessage(OPERATION);

            % Process input parameters and build full api url
            apiURL = obj.buildApiURL(serverOptions.Server, ENDPOINT_PATH, requiredParams, optionalParams);
            apiURL = appendRestrictToSpaces(apiURL, repeatedParams);
            apiURL = appendFilterParameters(apiURL, filterOptions.QueryParameters);

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
                obj.throwError("runQueryById", resp, serverOptions.Server)
            end
        end
    end
end

function apiURL = appendRestrictToSpaces(apiURL, repeatedParams)
% appendRestrictToSpaces - Add one restrictToSpaces parameter per space
%
%   The query endpoints expect restrictToSpaces to be repeated once per
%   space. buildApiURL would join the spaces into a single comma separated
%   value, which the server reads as one space name.

    if ~isfield(repeatedParams, 'restrictToSpaces')
        return
    end

    for i = 1:numel(repeatedParams.restrictToSpaces)
        apiURL.Query(end+1) = matlab.net.QueryParameter(...
            "restrictToSpaces", repeatedParams.restrictToSpaces(i));
    end
end

function apiURL = appendFilterParameters(apiURL, filterParams)
% appendFilterParameters - Add the query's own filter parameters to the URL
%
%   A filter in a query specification declares the name of the parameter it
%   reads with "parameter": "NAME". The endpoint collects every request
%   parameter it does not recognise itself and uses those values for the
%   matching filters, so each one is sent under its own name.

    % Names the endpoint binds to its own request parameters. It strips
    % some of them before the query runs and keeps others in the parameter
    % map, so a filter of one of these names silently reads the wrong
    % value, or none at all, instead of failing.
    RESERVED_NAMES = ["stage", "from", "size", "returnTotalResults", ...
        "instanceId", "restrictToSpaces"];

    names = string(fieldnames(filterParams))';

    isReserved = ismember(names, RESERVED_NAMES);
    if any(isReserved)
        offending = names(isReserved);
        if isscalar(offending)
            subject = "the name " + "'" + offending + "'";
        else
            subject = "the names " + strjoin("'" + offending + "'", ", ");
        end
        error("EBRAINS:KG_API:ReservedQueryParameter", ...
            "QueryParameters must not contain %s. The endpoint reads each " + ...
            "of these as one of its own request parameters, so the filter " + ...
            "never receives the given value. Rename the filter parameter " + ...
            "in the query specification.", subject)
    end

    for name = names
        apiURL.Query(end+1) = matlab.net.QueryParameter(name, filterParams.(name));
    end
end
