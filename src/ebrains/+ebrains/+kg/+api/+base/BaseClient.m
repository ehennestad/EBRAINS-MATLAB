classdef BaseClient < ebrains.common.internal.HttpClient
% BaseClient - Knowledge Graph specifics shared by the KG API clients
%
%   Resolves the KG server of a request to its base URL and names the
%   server in the report of a server error. Request building, sending and
%   error formatting are inherited from ebrains.common.internal.HttpClient.
%
%   See also ebrains.kg.api.InstancesClient, ebrains.kg.api.QueriesClient

    properties (Constant, Access = protected)
        ErrorIdPrefix = "EBRAINS:KG_API"
    end

    methods (Access = protected)
        function throwError(obj, operationName, response, server)
        % throwError - Throw the error for a failed KG response
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

    methods (Static, Access = protected)
        function apiURL = buildApiURL(server, endpointPath, requiredParams, optionalParams)
        % buildApiURL - URI of an endpoint on the given KG server
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
