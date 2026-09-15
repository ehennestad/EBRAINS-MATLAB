classdef AuthenticateTest < ebrains.test.iam.TokenClientTestCase
    % AuthenticateTest - Unit tests for ebrains.authenticate
    %
    % A mock client is installed where instance() looks for the singleton,
    % so the function drives the mock instead of a real login.

    methods (Test)
        function testDeviceFlowLogsInWhenThereIsNoToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient(ebrains.common.constant.OIDCClientID());
            client.addPollResponse('OK', testCase.makeTokenResponse());
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            ebrains.authenticate();

            testCase.verifyTrue(client.hasActiveToken());
            testCase.verifyEqual(client.PollCount, 1);
        end

        function testDeviceFlowLeavesAnActiveTokenAlone(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient(ebrains.common.constant.OIDCClientID());
            client.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            ebrains.authenticate();

            testCase.verifyEqual(client.PollCount, 0);
            testCase.verifyEmpty(client.TokenRequests);
        end

        function testRefreshModeRenewsAnActiveToken(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient(ebrains.common.constant.OIDCClientID());
            client.seedTokens("access-0", "refresh-0", 7200);
            client.addTokenResponse(testCase.makeTokenResponse("access-1"));
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            ebrains.authenticate("refresh");

            testCase.verifyEqual(client.AccessToken, "access-1");
            testCase.verifyEqual(client.TokenRequests{1}{2}, "refresh_token");
        end

        function testDeviceFlowWarnsWhenASecretIsGiven(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient("my-client");
            client.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            testCase.verifyWarning(...
                @() ebrains.authenticate("OAuthFlow", "DeviceFlow", ...
                    "OIDCClientID", "my-client", "OIDCClientSecret", "unused"), ...
                'EBRAINS:authenticate:SecretNotSupported');
        end

        function testClientCredentialsFlowUsesTheInstalledClient(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("service", "secret");
            client.addTokenResponse(struct('access_token', 'abc', 'expires_in', 7200));
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            ebrains.authenticate("OAuthFlow", "ClientCredentialsFlow", ...
                "OIDCClientID", "service", "OIDCClientSecret", "secret");

            testCase.verifyEqual(client.AccessToken, "abc");
            testCase.verifyNumElements(client.TokenRequests, 1);
        end
    end
end
