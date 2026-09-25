classdef MockHttpClient < ebrains.common.internal.HttpClient & ebrains.mocks.MockHttpTransport
    % MockHttpClient - Minimal concrete client for testing the shared HTTP base
    %
    % Exposes the protected request and error helpers of
    % ebrains.common.internal.HttpClient so that tests can exercise them
    % without the API client of a real service.
    %
    % Requests are built without a token unless UseTokenManager is true, in
    % which case the headers come from HttpClient.getDefaultHeader and its
    % token lookup. Tests that set it install mock token clients first.

    properties (Constant, Access = protected)
        ErrorIdPrefix = "EBRAINS:Test"
    end

    properties
        UseTokenManager (1,1) logical = false
    end

    methods
        function request = buildRequest(obj, method)
            request = obj.initializeRequestMessage(method);
        end

        function request = buildJsonRequest(obj, method, jsonPayload)
            request = obj.initializeRequestMessage(method, JSONPayload=jsonPayload);
        end

        function response = dispatch(obj, request, apiUri)
            response = obj.sendRequest(request, apiUri);
        end

        function exception = buildError(obj, operationName, response, options)
            arguments
                obj (1,1) ebrains.mocks.MockHttpClient
                operationName (1,1) string
                response (1,1) matlab.net.http.ResponseMessage
                options.Description (1,1) string = missing
            end
            exception = obj.createResponseError(operationName, response, ...
                Description=options.Description);
        end

        function raiseError(obj, operationName, response)
            obj.throwError(operationName, response);
        end
    end

    methods (Access = protected)
        function headers = getDefaultHeader(obj)
            if obj.UseTokenManager
                headers = getDefaultHeader@ebrains.common.internal.HttpClient(obj);
            else
                headers = obj.getMockHeaders();
            end
        end

        function response = transmitRequest(obj, requestObj, apiURL, httpOpts)
            arguments
                obj (1,1) ebrains.mocks.MockHttpClient
                requestObj (1,1) matlab.net.http.RequestMessage
                apiURL (1,1) matlab.net.URI
                httpOpts matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            response = obj.recordAndRespond(requestObj, apiURL, httpOpts);
        end
    end
end
