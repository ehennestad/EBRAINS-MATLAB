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
    end
end
