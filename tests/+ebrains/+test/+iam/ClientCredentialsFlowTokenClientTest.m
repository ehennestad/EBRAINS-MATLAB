classdef ClientCredentialsFlowTokenClientTest < ebrains.test.iam.TokenClientTestCase
    % ClientCredentialsFlowTokenClientTest - Unit tests for ebrains.iam.ClientCredentialsFlowTokenClient
    %
    % The flow is driven through the mock; the singleton lifecycle through
    % the real class, which needs no network until a token is requested.

    methods (Test)
        %% fetchToken
        function testFetchTokenPostsCredentials(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("my-client", "my-secret");
            client.addTokenResponse(struct('access_token', 'abc', 'expires_in', 7200));

            client.authenticate();

            formFields = client.TokenRequests{1};
            testCase.verifyEqual(formFields, {"grant_type", "client_credentials", ...
                "client_id", "my-client", "client_secret", "my-secret"});
            testCase.verifyEqual(client.AccessToken, "abc");
            testCase.verifyGreaterThan(client.ExpiresIn, minutes(119));
        end

        function testFetchTokenRethrowsInvalidCredentials(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.addTokenResponse(MException('MATLAB:webservices:HTTP400StatusCodeError', 'bad request'));

            testCase.verifyError(@() client.authenticate(), 'MATLAB:webservices:HTTP400StatusCodeError');
        end

        function testFetchTokenRethrowsUnauthorized(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.addTokenResponse(MException('MATLAB:webservices:HTTP401StatusCodeError', 'unauthorized'));

            testCase.verifyError(@() client.authenticate(), 'MATLAB:webservices:HTTP401StatusCodeError');
        end

        function testFetchTokenRethrowsOtherFailures(testCase)
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.addTokenResponse(MException('MATLAB:webservices:Timeout', 'timed out'));

            testCase.verifyError(@() client.authenticate(), 'MATLAB:webservices:Timeout');
        end

        function testRefreshFetchesANewToken(testCase)
            % The flow has no refresh token, so a refresh is a new request
            % with the credentials.
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient();
            client.addTokenResponse(struct('access_token', 'first', 'expires_in', 7200));
            client.addTokenResponse(struct('access_token', 'second', 'expires_in', 7200));

            client.authenticate();
            client.authenticate();

            testCase.verifyEqual(client.AccessToken, "second");
            testCase.verifyEqual(client.TokenRequests{2}{2}, "client_credentials");
        end

        %% Singleton lifecycle
        % These construct the real class. A token in the environment keeps
        % the constructor away from the secret store, which is slow to probe
        % on a headless runner.
        function testInstanceIsReusedForSameCredentials(testCase)
            setenv("EBRAINS_TOKEN", ebrains.mocks.makeTestJwt());
            first = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");
            second = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");

            testCase.verifySameHandle(second, first);
            testCase.verifyEqual(first.ClientId, "id");
        end

        function testInstanceWithOtherCredentialsWarnsAndReplaces(testCase)
            setenv("EBRAINS_TOKEN", ebrains.mocks.makeTestJwt());
            first = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");

            second = testCase.verifyWarning(...
                @() ebrains.iam.ClientCredentialsFlowTokenClient.instance("other", "secret"), ...
                'EBRAINS:IAM:CredentialsChanged');

            testCase.verifyNotSameHandle(second, first);
            testCase.verifyEqual(second.ClientId, "other");
        end

        function testResetDeletesTheInstance(testCase)
            setenv("EBRAINS_TOKEN", ebrains.mocks.makeTestJwt());
            first = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");

            ebrains.iam.ClientCredentialsFlowTokenClient.reset();

            testCase.verifyFalse(isvalid(first));
            second = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");
            testCase.verifyTrue(isvalid(second));
        end
    end
end
