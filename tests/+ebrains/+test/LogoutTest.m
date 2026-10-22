classdef LogoutTest < ebrains.test.iam.TokenClientTestCase
    % LogoutTest - Unit tests for ebrains.logout
    %
    % Mock clients holding tokens are installed where instance() looks for
    % the singletons, so that logging out has something to remove.

    methods (Test)
        function testRemovesTheClientsOfBothFlows(testCase)
            deviceClient = ebrains.mocks.MockDeviceFlowTokenClient();
            deviceClient.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, deviceClient);

            serviceClient = ebrains.mocks.MockClientCredentialsFlowTokenClient("service", "secret");
            serviceClient.seedToken("abc", 7200);
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, serviceClient);

            ebrains.logout();

            testCase.verifyFalse(isvalid(deviceClient));
            testCase.verifyFalse(isvalid(serviceClient));
        end

        function testLeavesNoTokenForTheNextRequest(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.seedTokens("access-0", "refresh-0", 7200);
            testCase.installSingleton(testCase.DeviceFlowSingletonName, client);

            ebrains.logout();

            testCase.verifyEmpty(ebrains.getTokenManager(Interactive=false));
        end

        function testWithoutClientsIsWarningFree(testCase)
            testCase.verifyWarningFree(@() ebrains.logout());
        end

        function testWarnsWhenTheEnvironmentHoldsAToken(testCase)
            % The next client created loads the token again, so the
            % session is not logged out for long, and the user is told so.
            setenv("EBRAINS_TOKEN", "not-a-real-token");

            testCase.verifyWarning(@() ebrains.logout(), ...
                'EBRAINS:logout:EnvironmentTokenSet');
        end
    end
end
