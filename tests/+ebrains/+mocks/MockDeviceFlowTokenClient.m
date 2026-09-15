classdef MockDeviceFlowTokenClient < ebrains.iam.DeviceFlowTokenClient & ebrains.mocks.MockOidcTransport
    % MockDeviceFlowTokenClient - Device-flow client with canned answers and no display
    %
    % The device authorization, the polling of the token endpoint, the
    % browser, and the progress box are all answered here, so the whole
    % login runs without a network or a figure.
    %
    % Example:
    %   client = ebrains.mocks.MockDeviceFlowTokenClient();
    %   client.addPollResponse('BadRequest', struct('error', 'authorization_pending'));
    %   client.addPollResponse('OK', struct('access_token', 'a', 'refresh_token', 'r', ...
    %       'expires_in', 3600, 'refresh_expires_in', 7200));
    %   client.authenticate();

    properties
        DeviceResponse = struct(...
            'device_code', 'device-code-1', ...
            'verification_uri_complete', 'https://iam.test/device?user_code=ABCD', ...
            'interval', 0, ...
            'expires_in', 60)
        PollResponses = {}      % Queue of matlab.net.http.ResponseMessage for sendTokenRequest
        PollCount = 0
        DeviceAuthorizationRequestCount = 0
        OpenedUrls string = string.empty(1, 0)
        Dialog = []             % The SpyLoginDialog of the last login
    end

    methods
        function obj = MockDeviceFlowTokenClient(clientId)
            arguments
                clientId (1,1) string = "test-client"
            end
            obj@ebrains.iam.DeviceFlowTokenClient(clientId);
        end

        function addPollResponse(obj, statusCode, data)
            % Queue the response of the next poll of the token endpoint
            body = matlab.net.http.MessageBody(data);
            obj.PollResponses{end+1} = matlab.net.http.ResponseMessage(...
                matlab.net.http.StatusCode(statusCode), [], body);
        end

        function seedTokens(obj, accessToken, refreshToken, expiresIn)
            % Put the client in the state of having completed a login
            obj.AccessToken_ = accessToken;
            obj.RefreshToken = refreshToken;
            obj.AccessTokenExpiresAt = datetime("now") + seconds(expiresIn);
            obj.RefreshTokenExpiresAt = datetime("now") + seconds(2*expiresIn);
        end
    end

    methods (Access = protected)
        function config = requestOpenIdConfiguration(obj)
            config = obj.fakeOpenIdConfiguration();
        end

        function token = readTokenFromSecretStore(~)
            % Probing the real store takes seconds on a headless runner and
            % is never part of a unit test; only the environment counts.
            token = string(missing);
        end

        function deviceResponse = requestDeviceAuthorization(obj)
            obj.getOpenIdConfig(); % resolved for the endpoint, as the real method does
            obj.DeviceAuthorizationRequestCount = obj.DeviceAuthorizationRequestCount + 1;
            deviceResponse = obj.DeviceResponse;
        end

        function response = sendTokenRequest(obj, ~)
            obj.getOpenIdConfig(); % resolved for the endpoint, as the real method does
            obj.PollCount = obj.PollCount + 1;
            if isempty(obj.PollResponses)
                error('MockDeviceFlowTokenClient:NoMoreResponses', ...
                    'No more poll responses queued; %d polls were made.', obj.PollCount);
            end
            response = obj.PollResponses{1};
            obj.PollResponses(1) = [];
        end

        function openVerificationPage(obj, url)
            obj.OpenedUrls(end+1) = string(url);
        end

        function dialog = createLoginDialog(obj)
            obj.Dialog = ebrains.mocks.SpyLoginDialog();
            dialog = obj.Dialog;
        end

        function tokenResponse = requestToken(obj, formFields)
            obj.getOpenIdConfig(); % resolved for the endpoint, as the real method does
            tokenResponse = obj.respondToTokenRequest(formFields);
        end

        function showErrorDialog(obj, titleMessage, errorMessage)
            obj.recordErrorDialog(titleMessage, errorMessage);
        end
    end
end
