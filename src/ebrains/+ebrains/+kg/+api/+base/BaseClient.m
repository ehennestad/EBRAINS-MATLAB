classdef BaseClient < handle %KGClient
    methods (Access = protected)
        function req = initializeRequestMessage(obj, operationName, options)
            arguments
                obj
                operationName (1,1) string
                options.JSONPayload (1,1) string = missing
            end

            headers = obj.getDefaultHeader();
            req  = matlab.net.http.RequestMessage(char(operationName), headers);

            if ~ismissing(options.JSONPayload)
                % Todo: Add header with content-type json here...
                body = matlab.net.http.MessageBody();
                body.Payload = char(options.JSONPayload);
                req.Body = body;
            end
        end

        function headers = getDefaultHeader(~)
            tokenManager = ebrains.getTokenManager();

            headers = [ ...
                matlab.net.http.HeaderField("Content-Type", "application/json"), ...
                matlab.net.http.HeaderField("Accept", "application/json") ...
                matlab.net.http.field.AuthorizationField("Authorization", "Bearer " + tokenManager.AccessToken) ...
                ];
        end

        function response = sendRequest(obj, requestObj, apiURL, httpOpts)
            arguments
                obj (1,1) ebrains.kg.api.base.BaseClient %#ok<INUSA>
                requestObj (1,1) matlab.net.http.RequestMessage
                apiURL (1,1) matlab.net.URI
                httpOpts matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            if isempty(httpOpts)
                response = requestObj.send(apiURL);
            else
                response = requestObj.send(apiURL, httpOpts);
            end
        end
    end

    methods (Static, Access = protected)
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