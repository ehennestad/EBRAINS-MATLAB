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

        function testClientCredentialsFlowIgnoresTheOrderOfTheOptions(testCase)
            % instance() takes the id and the secret positionally. Giving
            % them the other way round must still authenticate as the same
            % client: swapped values would be a different client, which
            % instance() would report through CredentialsChanged before
            % replacing the one installed here.
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("service", "secret");
            client.addTokenResponse(struct('access_token', 'abc', 'expires_in', 7200));
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            testCase.verifyWarningFree(@() ebrains.authenticate(...
                "OAuthFlow", "ClientCredentialsFlow", ...
                "OIDCClientSecret", "secret", "OIDCClientID", "service"));

            testCase.verifyNumElements(client.TokenRequests, 1);
            testCase.verifyEqual(client.AccessToken, "abc");
        end

        function testClientCredentialsFlowNeedsBothCredentials(testCase)
            % Half a set of credentials would authenticate as a client with
            % an empty id or an empty secret.
            testCase.verifyError(...
                @() ebrains.authenticate("OAuthFlow", "ClientCredentialsFlow", ...
                    "OIDCClientID", "service"), ...
                'EBRAINS:authenticate:IncompleteCredentials');

            testCase.verifyError(...
                @() ebrains.authenticate("OAuthFlow", "ClientCredentialsFlow", ...
                    "OIDCClientSecret", "secret"), ...
                'EBRAINS:authenticate:IncompleteCredentials');
        end
    end
end
