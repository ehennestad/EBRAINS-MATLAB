classdef QueriesClient < ebrains.kg.api.base.BaseClient

    methods
        function result = listQueries(obj, optionalParams, serverOptions)
        % listInstances - Returns a list of instances according to their types.

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
        % getQuery - Download the stored KG query for the given identifier.
        %
        % Syntax:
        %   query = client.getQuery(identifier)
        %   query = client.getQuery(identifier, RawOutput=true)
        %
        % Input Arguments:
        %   identifier string       - Identifier of the query, either a full KG
        %                             instance IRI or a bare UUID.
        %   RawOutput (1,1) logical - If true, return the unparsed response payload
        %                             exactly as returned by the server, preserving
        %                             the original JSON-LD keys. Default is false.
        %
        % Output Arguments:
        %   query - The query definition. A decoded struct when RawOutput is
        %           false, or the raw response payload when RawOutput is true.

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
