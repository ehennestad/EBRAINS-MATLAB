classdef (Abstract) HttpClient < handle
% HttpClient - Request building, sending and error reporting shared by API clients
%
%   Each EBRAINS service client derives from this class and adds one method
%   per endpoint. A method builds its request with initializeRequestMessage,
%   resolves the endpoint with ebrains.common.internal.buildApiUri, sends the
%   request with sendRequest and reports a failed response with throwError.
%   Every request carries the access token of the active token manager.
%
%   Subclasses set ErrorIdPrefix, which starts the identifier of every error
%   thrown for a failed response: <ErrorIdPrefix>:<operation>:<status name>.
%
%   Test doubles override getDefaultHeader and sendRequest so that no token
%   is needed and no request reaches a server.
%
%   See also ebrains.kg.api.base.BaseClient, ebrains.bucket.api.BucketsClient,
%   ebrains.collab.api.CollabsClient

    properties (Abstract, Constant, Access = protected)
        ErrorIdPrefix (1,1) string
    end

    methods (Access = protected)
        function request = initializeRequestMessage(obj, method, options)
        % initializeRequestMessage - Create a request with the default headers
        %
        %   request = obj.initializeRequestMessage(method) creates a request
        %   for the given HTTP method (e.g. "GET") without a body.
        %
        %   request = obj.initializeRequestMessage(method, JSONPayload=json)
        %   also sets the given JSON text as the body of the request.

            arguments
                obj (1,1) ebrains.common.internal.HttpClient
                method (1,1) string
                options.JSONPayload (1,1) string = missing
            end

            headers = obj.getDefaultHeader();
            request = matlab.net.http.RequestMessage(char(method), headers);

            if ~ismissing(options.JSONPayload)
                % The payload is already JSON text, so it is assigned to the
                % body as is instead of being encoded again by MessageBody.
                body = matlab.net.http.MessageBody();
                body.Payload = char(options.JSONPayload);
                request.Body = body;
            end
        end

        function headers = getDefaultHeader(~)
        % getDefaultHeader - Header fields for a JSON request with the active token
            tokenManager = ebrains.getTokenManager();

            % The token manager is asked for the ready Authorization field
            % rather than for the token to build one from, so that the bare
            % token is never handled here. getAuthHeaderField composes the
            % same field this did by hand.
            headers = [ ...
                matlab.net.http.HeaderField("Content-Type", "application/json"), ...
                matlab.net.http.HeaderField("Accept", "application/json"), ...
                tokenManager.getAuthHeaderField() ...
                ];
        end

        function response = sendRequest(obj, request, apiUri, httpOptions)
        % sendRequest - Send a request and return the response
            arguments
                obj (1,1) ebrains.common.internal.HttpClient %#ok<INUSA>
                request (1,1) matlab.net.http.RequestMessage
                apiUri (1,1) matlab.net.URI
                httpOptions matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            if isempty(httpOptions)
                response = request.send(apiUri);
            else
                response = request.send(apiUri, httpOptions);
            end
        end

        function throwError(obj, operationName, response, options)
        % throwError - Throw the error for a failed response
        %
        %   obj.throwError(operationName, response) throws an error whose
        %   identifier is <ErrorIdPrefix>:<operationName>:<status name> and
        %   whose message holds the status name and the text of the
        %   response body.
        %
        %   obj.throwError(..., Description=text) puts the given text in
        %   the message instead of the response body.

            arguments
                obj (1,1) ebrains.common.internal.HttpClient
                operationName (1,1) string
                response (1,1) matlab.net.http.ResponseMessage
                options.Description (1,1) string = missing
            end

            exception = obj.createResponseError(operationName, response, ...
                Description=options.Description);

            % Thrown as caller so that the error points at the API method
            % the user called rather than at this helper.
            throwAsCaller(exception)
        end

        function exception = createResponseError(obj, operationName, response, options)
        % createResponseError - Build the exception for a failed response
            arguments
                obj (1,1) ebrains.common.internal.HttpClient
                operationName (1,1) string
                response (1,1) matlab.net.http.ResponseMessage
                options.Description (1,1) string = missing
            end

            % char gives the name of the status (e.g. NotFound), whereas
            % string would give its number.
            statusName = string(char(response.StatusCode));
            errorId = sprintf('%s:%s:%s', obj.ErrorIdPrefix, operationName, statusName);

            if ismissing(options.Description)
                description = ebrains.common.internal.getResponseBodyText(response);
            else
                description = options.Description;
            end

            if strlength(description) == 0
                errorMessage = statusName;
            else
                errorMessage = statusName + ": " + description;
            end

            % The message goes through a format specifier so that "%" or "\"
            % in the server's text is not interpreted by MException.
            exception = MException(errorId, '%s', char(errorMessage));
        end
    end

    methods (Static, Access = protected)
        function httpOptions = getOptionsForRawResponse()
        % getOptionsForRawResponse - Options that leave the response body unconverted
            httpOptions = matlab.net.http.HTTPOptions('ConvertResponse', false);
        end
    end
end
