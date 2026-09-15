classdef OidcTokenClientTest < ebrains.test.iam.TokenClientTestCase
    % OidcTokenClientTest - Unit tests for the behaviour shared by the token clients
    %
    % Uses the client-credentials mock for token state, and the device-flow
    % mock where the base class's own refreshToken is under test, since the
    % client-credentials flow replaces it.

    methods (Test)
        %% Token state
        function testNoTokenWithoutEnvironment(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();

            testCase.verifyFalse(client.hasActiveToken());
            testCase.verifyFalse(client.canAuthenticate());
            testCase.verifyTrue(ismissing(client.ExpiresIn));
        end

        function testTokenFromEnvironmentIsUsedWithoutRequest(testCase)
            token = ebrains.mocks.makeTestJwt();
            setenv("EBRAINS_TOKEN", token);
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();

            testCase.verifyTrue(client.hasActiveToken());
            testCase.verifyTrue(client.canAuthenticate());
            testCase.verifyEqual(client.AccessToken, token);
            testCase.verifyGreaterThan(client.ExpiresIn, minutes(59)); % the helper's default expiry is an hour
            testCase.verifyEmpty(client.TokenRequests);
        end

        function testExpiredTokenIsInactiveAndWarns(testCase)
            expiredAt = round(posixtime(datetime("now", TimeZone="UTC"))) - 600;
            setenv("EBRAINS_TOKEN", ebrains.mocks.makeTestJwt(struct('exp', expiredAt)));
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();

            isActive = testCase.verifyWarning(@() client.hasActiveToken(), 'EBRAINS:IAM:TokenExpired');

            testCase.verifyFalse(isActive);
        end

        function testTokenExpiringSoonWarnsOncePerTenMinutes(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.seedToken("soon", 1800);

            isActive = testCase.verifyWarning(@() client.hasActiveToken(), 'EBRAINS:IAM:TokenExpiresSoon');
            testCase.verifyTrue(isActive);
            testCase.verifyWarningFree(@() client.hasActiveToken());
        end

        %% Requests
        function testConfigurationIsFetchedOnFirstTokenRequestOnly(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            testCase.verifyEqual(client.ConfigurationRequestCount, 0);
            client.addTokenResponse(struct('access_token', 'first', 'expires_in', 7200));
            client.addTokenResponse(struct('access_token', 'second', 'expires_in', 7200));

            client.authenticate();
            client.authenticate();

            testCase.verifyEqual(client.ConfigurationRequestCount, 1);
            testCase.verifyNumElements(client.TokenRequests, 2);
        end

        function testAccessTokenIsFetchedWhenMissing(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.addTokenResponse(struct('access_token', 'fetched', 'expires_in', 7200));

            testCase.verifyEqual(client.AccessToken, "fetched");
            testCase.verifyNumElements(client.TokenRequests, 1);
        end

        function testAccessTokenIsRenewedWhenExpired(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.seedToken("stale", -60);
            client.addTokenResponse(struct('access_token', 'renewed', 'expires_in', 7200));

            accessToken = testCase.verifyWarning(@() client.AccessToken, 'EBRAINS:IAM:TokenExpired');

            testCase.verifyEqual(accessToken, "renewed");
        end

        function testAuthorizationHeaderCarriesBearerToken(testCase)
            token = ebrains.mocks.makeTestJwt();
            setenv("EBRAINS_TOKEN", token);
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();

            authField = client.getAuthHeaderField();
            options = client.getWebOptions();

            testCase.verifyEqual(string(authField.Value), "Bearer " + token);
            testCase.verifyTrue(any(contains(string(options.HeaderFields), "Bearer " + token)));
        end

        function testDisplayMasksAccessToken(testCase)
            token = ebrains.mocks.makeTestJwt();
            setenv("EBRAINS_TOKEN", token);
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient(); %#ok<NASGU> read by evalc below

            displayText = evalc('disp(client)');

            testCase.verifySubstring(displayText, '********');
            testCase.verifyFalse(contains(displayText, token));
        end

        %% refreshToken of the base class
        function testRefreshUsesRefreshToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            client.addTokenResponse(testCase.makeTokenResponse("access-1"));

            client.authenticate();

            formFields = client.TokenRequests{1};
            testCase.verifyEqual(formFields{2}, "refresh_token");
            testCase.verifyEqual(formFields{6}, "refresh-0");
            testCase.verifyEqual(client.AccessToken, "access-1");
        end

        function testRefreshFallsBackToLoginOnBadRequest(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            client.addTokenResponse(MException('MATLAB:webservices:HTTP400StatusCodeError', 'invalid_grant'));
            client.addPollResponse('OK', testCase.makeTokenResponse("access-1"));

            client.authenticate();

            testCase.verifyEqual(client.PollCount, 1);
            testCase.verifyEqual(client.AccessToken, "access-1");
        end

        function testRefreshWithoutARefreshTokenLogsInOnce(testCase)
            % A token taken from EBRAINS_TOKEN comes without a refresh
            % token, so there is nothing to refresh with and the flow of
            % the subclass fetches one instead. That already leaves a fresh
            % token, so no refresh request follows it.
            setenv("EBRAINS_TOKEN", ebrains.mocks.makeTestJwt());
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('OK', testCase.makeTokenResponse("access-1"));

            client.authenticate();

            testCase.verifyEqual(client.PollCount, 1);
            testCase.verifyEmpty(client.TokenRequests);
            testCase.verifyEqual(client.AccessToken, "access-1");
        end

        function testRefreshFailureShowsDialogAndRethrows(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            client.addTokenResponse(MException('MATLAB:webservices:Timeout', 'timed out'));

            testCase.verifyError(@() client.authenticate(), 'MATLAB:webservices:Timeout');

            testCase.verifyEqual(client.ErrorDialogs(1).Title, "Token Refresh Failed");
            testCase.verifyEqual(client.PollCount, 0);
        end
    end
end
