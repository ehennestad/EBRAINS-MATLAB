classdef AuthenticateTest < ebrains.test.iam.TokenClientTestCase
    % AuthenticateTest - Unit tests for ebrains.authenticate
    %
    % ebrains.authenticate is an alias of ebrains.login, whose behaviour is
    % covered by LoginTest. These tests check that each kind of argument
    % reaches ebrains.login, using the mock clients installed where
    % instance() looks for the singletons.

    methods (Test)
        function testForwardsTheMode(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient(ebrains.common.constant.OIDCClientID());
            client.seedTokens("access-0", "refresh-0", 7200);
            client.addTokenResponse(testCase.makeTokenResponse("access-1"));
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            ebrains.authenticate("refresh");

            testCase.verifyEqual(client.AccessToken, "access-1");
        end

        function testForwardsTheNameValueArguments(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("service", "secret");
            client.addTokenResponse(struct('access_token', 'abc', 'expires_in', 7200));
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, client);

            testCase.verifyWarningFree(@() ebrains.authenticate(...
                OAuthFlow="ClientCredentialsFlow", ...
                OIDCClientID="service", OIDCClientSecret="secret"));

            testCase.verifyEqual(client.AccessToken, "abc");
        end

        function testRaisesTheErrorsOfLogin(testCase)
            testCase.verifyError(...
                @() ebrains.authenticate(OAuthFlow="ClientCredentialsFlow", ...
                    OIDCClientID="service"), ...
                'EBRAINS:login:IncompleteCredentials');
        end
    end
end
