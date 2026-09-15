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

        function testExpiredEnvironmentTokenNamesTheVariableItCameFrom(testCase)
            % The client that carries EBRAINS_TOKEN has no credentials of
            % its own, so there is nothing to fetch a new token with once
            % that one expires. Requesting one with empty credentials made
            % the identity provider answer "invalid client credentials",
            % sending the caller to check credentials they never gave.
            expiredAt = round(posixtime(datetime("now", TimeZone="UTC"))) - 600;
            setenv("EBRAINS_TOKEN", ebrains.mocks.makeTestJwt(struct('exp', expiredAt)));
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("", "");

            exception = captureError(testCase, @() client.AccessToken);

            testCase.verifyEqual(exception.identifier, 'EBRAINS:IAM:MissingClientCredentials');
            testCase.verifySubstring(exception.message, 'EBRAINS_TOKEN');
            testCase.verifyEmpty(client.TokenRequests);
        end

        function testMissingCredentialsWithoutATokenAsksForThem(testCase)
            % Nothing was ever given to authenticate with, so the error
            % asks for the credentials rather than blaming a token.
            client = ebrains.mocks.MockClientCredentialsFlowTokenClient("", "");

            exception = captureError(testCase, @() client.authenticate());

            testCase.verifyEqual(exception.identifier, 'EBRAINS:IAM:MissingClientCredentials');
            testCase.verifySubstring(exception.message, 'OIDCClientID');
            testCase.verifyEmpty(client.TokenRequests);
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
        function testInstanceIsReusedForSameCredentials(testCase)
            first = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");
            second = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");

            testCase.verifySameHandle(second, first);
            testCase.verifyEqual(first.ClientId, "id");
        end

        function testInstanceWithOtherCredentialsWarnsAndReplaces(testCase)
            first = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");

            second = testCase.verifyWarning(...
                @() ebrains.iam.ClientCredentialsFlowTokenClient.instance("other", "secret"), ...
                'EBRAINS:IAM:CredentialsChanged');

            testCase.verifyNotSameHandle(second, first);
            testCase.verifyEqual(second.ClientId, "other");
        end

        function testInstanceTakesFirstCredentialsWithoutWarning(testCase)
            % getTokenManager creates a client without credentials to look
            % for a token, which every API call does. Authenticating with
            % the client credentials flow afterwards gives that client its
            % credentials for the first time; it is not a change of them.
            placeholder = ebrains.iam.ClientCredentialsFlowTokenClient.instance();

            client = testCase.verifyWarningFree(...
                @() ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret"));

            testCase.verifyNotSameHandle(client, placeholder);
            testCase.verifyEqual(client.ClientId, "id");
        end

        function testResetDeletesTheInstance(testCase)
            first = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");

            ebrains.iam.ClientCredentialsFlowTokenClient.reset();

            testCase.verifyFalse(isvalid(first));
            second = ebrains.iam.ClientCredentialsFlowTokenClient.instance("id", "secret");
            testCase.verifyTrue(isvalid(second));
        end
    end
end

function exception = captureError(testCase, fcn)
% captureError - The exception a call raises, for asserting on its message
%
%   verifyError checks the identifier but does not hand back the
%   exception, and the two errors of assertHasCredentials share one
%   identifier and differ in what they tell the caller to do.

    exception = MException.empty;
    try
        fcn();
    catch exception
    end
    testCase.assertNotEmpty(exception, "The call was expected to raise an error.")
end
