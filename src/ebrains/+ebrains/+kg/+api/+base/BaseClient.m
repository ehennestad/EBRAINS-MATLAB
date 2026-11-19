classdef BaseClient < ebrains.common.internal.HttpClient
%BaseClient - Knowledge Graph specifics shared by the KG API clients
%   BaseClient resolves the KG server of a request to its base URL and
%   names the server in the report of a server error. Request building,
%   sending and error formatting are inherited from
%   ebrains.common.internal.HttpClient. Subclass it to write a KG API
%   client; it has no public methods of its own.
%
%   The KG clients work in the "prod" environment only. The Server option
%   of a method selects between the KG servers of that environment, and
%   the toolbox has no KG server for the "int" environment. A request
%   made while the Environment preference is "int" raises
%   EBRAINS:KG_API:UnsupportedEnvironment before a token is looked up, so
%   that a token of the "int" identity provider is not sent to a KG
%   server.
%
%   See also ebrains.kg.api.InstancesClient, ebrains.kg.api.QueriesClient,
%   ebrains.useEnvironment

    properties (Constant, Access = protected)
        ErrorIdPrefix = "EBRAINS:KG_API"  % Prefix of the identifiers of raised errors
    end

    methods (Access = protected)
        function request = initializeRequestMessage(obj, method, options)
        %initializeRequestMessage - Create a request with the default headers
        %   Raises EBRAINS:KG_API:UnsupportedEnvironment unless the
        %   Environment preference is "prod". The check comes before the
        %   request is created because creating it looks up a token, and
        %   opens a login when the AutoLogin preference is true.

            arguments
                obj (1,1) ebrains.kg.api.base.BaseClient
                method (1,1) string
                options.JSONPayload (1,1) string = missing
            end

            obj.assertEnvironmentHasKnowledgeGraph()

            request = initializeRequestMessage@ebrains.common.internal.HttpClient( ...
                obj, method, JSONPayload=options.JSONPayload);
        end

        function throwError(obj, operationName, response, server)
        %throwError - Throw the error for a failed KG response

            arguments
                obj (1,1) ebrains.kg.api.base.BaseClient
                operationName (1,1) string
                response (1,1) matlab.net.http.ResponseMessage
                server (1,1) ebrains.kg.enum.KGServer
            end

            if response.StatusCode == 500
                % The body of a server error rarely explains anything, so
                % the message points at the server that failed instead.
                description = sprintf(...
                    'Something went wrong. Please verify that the KG server (%s) is working.', ...
                    server.Name);
                exception = obj.createResponseError(operationName, response, ...
                    Description=description);
            else
                exception = obj.createResponseError(operationName, response);
            end

            % Thrown as caller so that the error points at the API method
            % the user called rather than at this helper.
            throwAsCaller(exception)
        end
    end

    methods (Access = private)
        function assertEnvironmentHasKnowledgeGraph(obj)
        %assertEnvironmentHasKnowledgeGraph - Raise an error outside the "prod" environment

            environment = ebrains.getpref("Environment");
            if environment ~= ebrains.common.enum.Environment.PROD
                error(obj.ErrorIdPrefix + ":UnsupportedEnvironment", ...
                    "The Knowledge Graph clients work in the ""prod"" environment only, " + ...
                    "and the Environment preference is ""%s"". Run " + ...
                    "ebrains.useEnvironment(""prod"") before using the Knowledge Graph.", ...
                    environment.Name)
            end
        end
    end

    methods (Static, Access = protected)
        function apiURL = buildApiURL(server, endpointPath, requiredParams, optionalParams)
        %buildApiURL - URI of an endpoint on the given KG server

            arguments
                server (1,1) ebrains.kg.enum.KGServer
                endpointPath (1,1) string
                requiredParams = struct.empty
                optionalParams = struct.empty
            end

            serverUrl = ebrains.common.constant.KGCoreApiBaseURL("Server", server);

            % The path is given as text ("/instances/<id>"); each part
            % between the slashes becomes one segment of the URI.
            pathSegments = split(strip(endpointPath, "left", "/"), "/")';

            apiURL = ebrains.common.internal.buildApiUri(...
                serverUrl, pathSegments, requiredParams, optionalParams);
        end
    end
end
