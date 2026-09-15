classdef MockOidcTransport < handle
    % MockOidcTransport - Canned identity-provider answers for token client mocks
    %
    % Mix this class into a subclass of a token client and forward the
    % client's protected requestOpenIdConfiguration, requestToken, and
    % showErrorDialog to the methods here. The mock then answers from
    % queued responses instead of contacting EBRAINS IAM, and keeps every
    % request and dialog for later assertions.

    properties
        OpenIdConfiguration = struct(...
            'token_endpoint', 'https://iam.test/token', ...
            'device_authorization_endpoint', 'https://iam.test/device')
        TokenResponses = {}     % Queue for requestToken: a struct, or an MException to throw
        TokenRequests = {}      % The form fields of every requestToken call
        ConfigurationRequestCount = 0
        ErrorDialogs = struct('Title', {}, 'Message', {})
    end

    methods
        function addTokenResponse(obj, response)
            % Queue the answer of the next requestToken call
            %
            % Input Arguments:
            %   response - Struct decoded from the token endpoint, or an
            %              MException that the call should throw
            obj.TokenResponses{end+1} = response;
        end
    end

    methods (Access = protected)
        function config = fakeOpenIdConfiguration(obj)
            obj.ConfigurationRequestCount = obj.ConfigurationRequestCount + 1;
            config = obj.OpenIdConfiguration;
        end

        function response = respondToTokenRequest(obj, formFields)
            obj.TokenRequests{end+1} = formFields;
            if isempty(obj.TokenResponses)
                error('MockOidcTransport:NoMoreResponses', ...
                    'No more token responses queued; %d requests were made.', numel(obj.TokenRequests));
            end
            response = obj.TokenResponses{1};
            obj.TokenResponses(1) = [];
            if isa(response, 'MException')
                throw(response)
            end
        end

        function recordErrorDialog(obj, titleMessage, errorMessage)
            obj.ErrorDialogs(end+1) = struct('Title', string(titleMessage), 'Message', string(errorMessage));
        end
    end
end
