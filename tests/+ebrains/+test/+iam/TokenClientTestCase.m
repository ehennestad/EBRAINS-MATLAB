classdef (Abstract) TokenClientTestCase < matlab.unittest.TestCase
    % TokenClientTestCase - Shared setup for the tests of the token clients
    %
    % The token clients keep their singletons in the graphics root's
    % UserData, and read EBRAINS_TOKEN from the environment. Both belong to
    % the MATLAB session the tests run in, so each test starts with them
    % moved aside and gets them back afterwards. The session's own clients
    % are moved, not deleted; only the instances a test created are
    % deleted at teardown.
    %
    % The AutoLogin and AutoRenew preferences decide whether a token is
    % looked up with a login or a renewal, so each test also runs with the
    % default preferences (see ebrains.test.fixtures.PreferencesFixture).

    properties (Constant)
        DeviceFlowSingletonName = "IAM_DeviceFlow_Client"
        ClientCredentialsSingletonName = "IAM_ClientCredentials_Client"
    end

    methods (TestMethodSetup)
        function isolateSessionState(testCase)
            savedUserData = get(0, 'UserData');
            testCase.addTeardown(@() restoreSingletons(savedUserData));
            if isstruct(savedUserData) && isfield(savedUserData, 'SingletonInstances')
                set(0, 'UserData', rmfield(savedUserData, 'SingletonInstances'));
            end

            for name = ["EBRAINS_TOKEN", "EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW"]
                % Read here, before the test runs. Called inside the
                % teardown handle, isenv and getenv would read the value the
                % test left behind, and restore that instead.
                wasSet = isenv(name);
                value = getenv(name);
                testCase.addTeardown(@() restoreEnvironmentVariable(name, wasSet, value));
                unsetenv(name);
            end

            testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());
        end
    end

    methods
        function installSingleton(testCase, singletonName, client)
        % installSingleton - Put a client where instance() will find it
            arguments
                testCase %#ok<INUSA>
                singletonName (1,1) string
                client (1,1) ebrains.iam.OidcTokenClient
            end
            rootUserData = get(0, 'UserData');
            rootUserData.SingletonInstances.(singletonName) = client;
            set(0, 'UserData', rootUserData);
        end

        function tokenResponse = makeTokenResponse(~, accessToken)
        % makeTokenResponse - Body of a successful token endpoint answer
            arguments
                ~
                accessToken (1,1) string = "access-1"
            end
            tokenResponse = struct(...
                'access_token', char(accessToken), ...
                'refresh_token', 'refresh-1', ...
                'expires_in', 7200, ...
                'refresh_expires_in', 14400);
        end
    end
end

function restoreSingletons(savedUserData)
    ebrains.iam.OidcTokenClient.resetAll()
    set(0, 'UserData', savedUserData);
end

function restoreEnvironmentVariable(name, wasSet, value)
    if wasSet
        setenv(name, value);
    else
        unsetenv(name);
    end
end
