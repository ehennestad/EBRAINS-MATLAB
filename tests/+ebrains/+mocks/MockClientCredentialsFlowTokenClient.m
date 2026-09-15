classdef MockClientCredentialsFlowTokenClient < ebrains.iam.ClientCredentialsFlowTokenClient & ebrains.mocks.MockOidcTransport
    % MockClientCredentialsFlowTokenClient - Client-credentials client with canned answers
    %
    % Example:
    %   client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
    %   client.addTokenResponse(struct('access_token', 'abc', 'expires_in', 3600));
    %   client.authenticate();

    methods
        function obj = MockClientCredentialsFlowTokenClient(clientId, clientSecret)
            arguments
                clientId (1,1) string = "test-client"
                clientSecret (1,1) string = "test-secret"
            end
            obj@ebrains.iam.ClientCredentialsFlowTokenClient(clientId, clientSecret);
        end

        function seedToken(obj, accessToken, expiresIn)
            % Put the client in the state of having fetched a token
            obj.AccessToken_ = accessToken;
            obj.AccessTokenExpiresAt = datetime("now") + seconds(expiresIn);
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

        function tokenResponse = requestToken(obj, formFields)
            obj.getOpenIdConfig(); % resolved for the endpoint, as the real method does
            tokenResponse = obj.respondToTokenRequest(formFields);
        end

        function showErrorDialog(obj, titleMessage, errorMessage)
            obj.recordErrorDialog(titleMessage, errorMessage);
        end
    end
end
