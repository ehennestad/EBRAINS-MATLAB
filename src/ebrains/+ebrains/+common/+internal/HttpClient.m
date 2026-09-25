classdef (Abstract) HttpClient < handle
% HttpClient - Request building, sending and error reporting shared by API clients
%
%   Each EBRAINS service client derives from this class and adds one method
%   per endpoint. A method builds its request with initializeRequestMessage,
%   resolves the endpoint with ebrains.common.internal.buildApiUri, sends the
%   request with sendRequest and reports a failed response with throwError.
%
%   A request carries an access token when ebrains.getTokenManager finds
%   one. With the AutoLogin preference false (the default), no request
%   starts a login, and a request is sent without a token when none is
%   available. The Data Proxy answers requests without a token for public
%   buckets, and the Collaboratory for public collabs. A request without a
%   token that the service refuses with 401 (Unauthorized) or 403
%   (Forbidden) is reported with a message that asks the user to run
%   ebrains.authenticate. With AutoLogin true, a request without an
%   available token opens the login first.
%
%   Subclasses set ErrorIdPrefix, which starts the identifier of every error
%   thrown for a failed response: <ErrorIdPrefix>:<operation>:<status name>.
%
%   Test doubles override getDefaultHeader and transmitRequest so that no
%   token is needed and no request reaches a server.
%
%   See also ebrains.kg.api.base.BaseClient, ebrains.bucket.api.BucketsClient,
%   ebrains.collab.api.CollabsClient

    properties (Abstract, Constant, Access = protected)
        ErrorIdPrefix (1,1) string
    end

    properties (Access = private)
        % Whether the request sent last carried an access token. The
        % response to it does not say, and a refusal is reported differently
        % for a request that was sent without one. Every method reports the
        % response of the request it has just sent, so the request sent
        % last is the one being reported.
        LastSentRequestHasToken (1,1) logical = false
    end

    methods (Sealed, Access = protected)
        function response = sendRequest(obj, request, apiUri, httpOptions)
        % sendRequest - Send a request and return the response
        %
        %   Sealed, so that a test double replaces only the transport
        %   (transmitRequest) and every request records whether it carried
        %   a token.
            arguments
                obj (1,1) ebrains.common.internal.HttpClient
                request (1,1) matlab.net.http.RequestMessage
                apiUri (1,1) matlab.net.URI
                httpOptions matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            obj.LastSentRequestHasToken = ~isempty(request.getFields("Authorization"));
            response = obj.transmitRequest(request, apiUri, httpOptions);
        end
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
        % getDefaultHeader - Header fields for a JSON request, with a token when one is available
            headers = [ ...
                matlab.net.http.HeaderField("Content-Type", "application/json"), ...
                matlab.net.http.HeaderField("Accept", "application/json") ...
                ];

            % Unless the AutoLogin preference asks for it, no login is started
            % for a request: public data needs no token, and a refusal of a
            % request without one is reported with a message that asks the
            % user to log in (see createResponseError).
            tokenManager = ebrains.getTokenManager( ...
                Interactive=ebrains.getpref("AutoLogin"));
            if ~isempty(tokenManager)
                % The Authorization field comes ready from the token
                % manager, so the bare token is never handled here.
                headers = [headers, tokenManager.getAuthHeaderField()];
            end
        end

        function response = transmitRequest(obj, request, apiUri, httpOptions)
        % transmitRequest - Send a request over the network and return the response
        %
        %   Called by sendRequest only. Test doubles override this method
        %   to answer without a server.
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
        %   response body. When the request was sent without a token and
        %   the status is 401 (Unauthorized) or 403 (Forbidden), the
        %   message asks the user to run ebrains.authenticate instead.
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

            % Without a token, the Data Proxy refuses a read of a private
            % bucket with 401 and a request for an upload URL with 403, and
            % the KG answers 401 with an empty body. None of these tells the
            % user that logging in is the fix, so the message leads with it.
            % The text of the server follows, since a refusal can have
            % another cause, such as a proxy that limits the request rate.
            % A request that did carry a token keeps only the text of the
            % server, which is the only account of why that token was
            % refused.
            refusalStatusCodes = [ ...
                matlab.net.http.StatusCode.Unauthorized, ...
                matlab.net.http.StatusCode.Forbidden];
            isRefusedWithoutToken = ~obj.LastSentRequestHasToken ...
                && ismember(response.StatusCode, refusalStatusCodes);

            if ~ismissing(options.Description)
                description = options.Description;
            elseif isRefusedWithoutToken
                description = "This request requires authentication. " + ...
                    "Run ebrains.authenticate() to log in to EBRAINS, then try again. " + ...
                    "To log in automatically when a request needs it, run " + ...
                    "ebrains.setpref(AutoLogin=true).";
                serverText = ebrains.common.internal.getResponseBodyText(response);
                if strlength(serverText) > 0
                    description = description + " The server answered: " + serverText;
                end
            else
                description = ebrains.common.internal.getResponseBodyText(response);
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
