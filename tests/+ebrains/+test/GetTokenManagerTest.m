classdef GetTokenManagerTest < ebrains.test.iam.TokenClientTestCase
    % GetTokenManagerTest - Unit tests for ebrains.getTokenManager
    %
    % Mock clients are installed where instance() looks for the singletons,
    % so the function picks between them without a real login.

    methods (TestMethodSetup)
        function installTokenlessClientCredentialsClient(testCase)
            % getTokenManager asks the client-credentials singleton first;
            % a mock there keeps the tests to the mocks. Tests that want that
            % client to be usable seed it a token.
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, ...
                ebrains.mocks.MockClientCredentialsFlowTokenClient());
        end
    end

    methods (Test)
        function testPrefersClientCredentialsClientThatCanAuthenticate(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.seedToken("abc", 7200);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, client);
        end

        function testPrefersClientCredentialsClientThatCanRenewItsToken(testCase)
            % A client with credentials fetches a new token on demand, so an
            % expired one is no reason to go looking for another flow.
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("service", "secret");
            client.seedToken("stale", -60);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, client);
        end

        function testUsesAValidTokenFromTheEnvironment(testCase)
            % The client without credentials is the one that carries a token
            % given through EBRAINS_TOKEN. It answers while that token lasts.
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("", "");
            client.seedToken("from-environment", 7200);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, client);
        end

        function testFallsBackToDeviceFlowWhenTheEnvironmentTokenHasExpired(testCase)
            % A token from EBRAINS_TOKEN cannot be renewed by the toolbox,
            % which holds no credentials for it. Answering with its client
            % anyway would fail every request over an expired token, and
            % would leave a device flow login with nothing to take effect on.
            expired = ebrains.mocks.MockClientCredentialsFlowTokenClient("", "");
            expired.seedToken("from-environment", -60);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, expired);

            deviceClient = ebrains.mocks.MockDeviceFlowTokenClient();
            deviceClient.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, deviceClient);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, deviceClient);
            testCase.verifyEqual(deviceClient.PollCount, 0);
        end

        function testErrorsWhenForcedClientCredentialsCannotAuthenticate(testCase)
            setenv("EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW", "true");

            testCase.verifyError(@() ebrains.getTokenManager(), 'EBRAINS:GetTokenManager:Unauthenticated');
        end

        function testReturnsDeviceFlowClientWithActiveToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, client);
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testLogsInDeviceFlowClientWithoutToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('OK', testCase.makeTokenResponse());
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, client);
            testCase.verifyEqual(client.PollCount, 1);
            testCase.verifyTrue(client.hasActiveToken());
        end

        function testErrorsWhenLoginLeavesNoActiveToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            alreadyExpired = testCase.makeTokenResponse();
            alreadyExpired.expires_in = -10;
            client.addPollResponse('OK', alreadyExpired);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            testCase.verifyError(@() ebrains.getTokenManager(), 'EBRAINS:GetTokenManager:TokenManagerNotFound');
        end

        %% Interactive=false
        function testNonInteractiveUsesClientCredentialsClient(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.seedToken("abc", 7200);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            tokenManager = ebrains.getTokenManager(Interactive=false);

            testCase.verifySameHandle(tokenManager, client);
        end

        function testNonInteractiveReturnsDeviceFlowClientWithActiveToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = ebrains.getTokenManager(Interactive=false);

            testCase.verifySameHandle(tokenManager, client);
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testNonInteractiveReturnsEmptyInsteadOfLoggingIn(testCase)
            % No poll response is queued, so a login attempt would error.
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = ebrains.getTokenManager(Interactive=false);

            testCase.verifyEmpty(tokenManager);
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testNonInteractiveReturnsEmptyForExpiredDeviceFlowToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", -60);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = testCase.verifyWarning(...
                @() ebrains.getTokenManager(Interactive=false, AutoRenew=false), ...
                'EBRAINS:IAM:TokenExpired');

            testCase.verifyEmpty(tokenManager);
            testCase.verifyEmpty(client.TokenRequests);
            testCase.verifyEqual(client.PollCount, 0);
        end

        %% AutoRenew
        function testAutoRenewRenewsExpiredDeviceFlowToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", -60);
            client.addTokenResponse(testCase.makeTokenResponse("access-1"));
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = testCase.verifyWarningFree(...
                @() ebrains.getTokenManager(Interactive=false, AutoRenew=true));

            testCase.verifySameHandle(tokenManager, client);
            testCase.verifyEqual(client.AccessToken, "access-1");
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testAutoRenewDoesNotLogInWhenRefreshIsRefused(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", -60);
            client.addTokenResponse(MException('MATLAB:webservices:HTTP400StatusCodeError', 'invalid_grant'));
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = testCase.verifyWarning(...
                @() ebrains.getTokenManager(Interactive=false, AutoRenew=true), ...
                'EBRAINS:IAM:TokenExpired');

            testCase.verifyEmpty(tokenManager);
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testFailedRenewalFallsBackToNoToken(testCase)
            % A timeout reaching the identity provider must not fail a
            % request that needs no token, such as a read of a public bucket.
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", -60);
            client.addTokenResponse(MException('MATLAB:webservices:Timeout', 'timed out'));
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = testCase.verifyWarning(...
                @() ebrains.getTokenManager(Interactive=false, AutoRenew=true), ...
                'EBRAINS:GetTokenManager:RenewalFailed');

            testCase.verifyEmpty(tokenManager);
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testAutoRenewComesBeforeLogin(testCase)
            % A renewal needs no browser, so it is tried before a login even
            % when a login is allowed.
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", -60);
            client.addTokenResponse(testCase.makeTokenResponse("access-1"));
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = ebrains.getTokenManager(AutoRenew=true);

            testCase.verifySameHandle(tokenManager, client);
            testCase.verifyEqual(client.PollCount, 0);
        end

        function testAutoRenewDefaultsToPreference(testCase)
            ebrains.setpref(AutoRenew=false);
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", -60);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            tokenManager = testCase.verifyWarning(...
                @() ebrains.getTokenManager(Interactive=false), 'EBRAINS:IAM:TokenExpired');

            testCase.verifyEmpty(tokenManager);
            testCase.verifyEmpty(client.TokenRequests);
        end

        function testNonInteractiveErrorsWhenForcedWithoutToken(testCase)
            % A job that forces the client credentials flow expects to
            % authenticate with its credentials. Sending its requests
            % without a token would fail with advice to log in through the
            % device flow, which the forced flow never uses. The device flow
            % client is ignored even when it holds an active token.
            setenv("EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW", "true");
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            testCase.verifyError(@() ebrains.getTokenManager(Interactive=false), ...
                'EBRAINS:GetTokenManager:Unauthenticated');
        end
    end
end
