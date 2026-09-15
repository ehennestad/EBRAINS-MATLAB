classdef GetTokenManagerTest < ebrains.test.iam.TokenClientTestCase
    % GetTokenManagerTest - Unit tests for ebrains.getTokenManager
    %
    % Mock clients are installed where instance() looks for the singletons,
    % so the function picks between them without a real login.

    methods (Test)
        function testPrefersClientCredentialsClientThatCanAuthenticate(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.seedToken("abc", 7200);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            tokenManager = ebrains.getTokenManager();

            testCase.verifySameHandle(tokenManager, client);
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
