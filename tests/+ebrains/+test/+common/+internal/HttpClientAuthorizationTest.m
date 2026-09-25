classdef HttpClientAuthorizationTest < ebrains.test.iam.TokenClientTestCase
    % HttpClientAuthorizationTest - Unit tests for the token handling of HttpClient
    %
    % A request carries a token when a token client can supply one without
    % a login, and goes without one otherwise, unless the AutoLogin
    % preference is true. A refusal of a request without a token asks the
    % user to run ebrains.authenticate.
    %
    % Mock token clients are installed where getTokenManager looks for the
    % singletons. The device flow mock has no poll responses queued, so a
    % login attempt fails the test instead of opening a browser.

    properties
        Client ebrains.mocks.MockHttpClient
        DeviceClient ebrains.mocks.MockDeviceFlowTokenClient
    end

    methods (TestMethodSetup)
        function installTokenlessClients(testCase)
            testCase.installSingleton(testCase.ClientCredentialsSingletonName, ...
                ebrains.mocks.MockClientCredentialsFlowTokenClient());

            testCase.DeviceClient = ebrains.mocks.MockDeviceFlowTokenClient();
            testCase.installSingleton(testCase.DeviceFlowSingletonName, testCase.DeviceClient);

            testCase.Client = ebrains.mocks.MockHttpClient();
            testCase.Client.UseTokenManager = true;
        end
    end

    methods (Test)
        %% Request building
        function testRequestWithoutTokenHasNoAuthorizationField(testCase)
            request = testCase.Client.buildRequest("GET");

            testCase.verifyEmpty(request.getFields("Authorization"));
            testCase.verifyEqual(testCase.DeviceClient.PollCount, 0);
        end

        function testRequestCarriesActiveToken(testCase)
            testCase.DeviceClient.seedTokens("access-0", "refresh-0", 7200);

            request = testCase.Client.buildRequest("GET");

            authField = request.getFields("Authorization");
            testCase.verifyEqual(string(authField.Value), "Bearer access-0");
        end

        function testAutoLoginLogsInBeforeRequestWithoutToken(testCase)
            ebrains.setpref(AutoLogin=true);
            testCase.DeviceClient.addPollResponse('OK', testCase.makeTokenResponse("access-1"));

            request = testCase.Client.buildRequest("GET");

            authField = request.getFields("Authorization");
            testCase.verifyEqual(string(authField.Value), "Bearer access-1");
            testCase.verifyEqual(testCase.DeviceClient.PollCount, 1);
        end

        %% Error reporting
        function testUnauthorizedWithoutTokenAsksForLogin(testCase)
            testCase.Client.buildRequest("GET");
            response = makeResponse('Unauthorized', 'You are not authenticated.');

            exception = testCase.Client.buildError("fetchThing", response);

            testCase.verifyEqual(exception.identifier, 'EBRAINS:Test:fetchThing:Unauthorized');
            testCase.verifySubstring(exception.message, 'requires authentication');
            testCase.verifySubstring(exception.message, 'ebrains.authenticate()');
            testCase.verifySubstring(exception.message, 'ebrains.setpref(AutoLogin=true)');
            testCase.verifySubstring(exception.message, 'The server answered: You are not authenticated.');
        end

        function testUnauthorizedWithoutBodyAsksForLogin(testCase)
            % The KG answers a request without a token with an empty body.
            testCase.Client.buildRequest("GET");
            response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.Unauthorized);

            exception = testCase.Client.buildError("fetchThing", response);

            testCase.verifySubstring(exception.message, 'ebrains.authenticate()');
            testCase.verifyFalse(contains(exception.message, 'The server answered'));
        end

        function testForbiddenWithoutTokenAsksForLogin(testCase)
            % The Data Proxy answers a request for an upload URL without a
            % token with 403.
            testCase.Client.buildRequest("PUT");
            response = makeResponse('Forbidden', 'Not authenticated');

            exception = testCase.Client.buildError("fetchThing", response);

            testCase.verifyEqual(exception.identifier, 'EBRAINS:Test:fetchThing:Forbidden');
            testCase.verifySubstring(exception.message, 'ebrains.authenticate()');
        end

        function testUnauthorizedWithTokenKeepsServerText(testCase)
            testCase.DeviceClient.seedTokens("access-0", "refresh-0", 7200);
            testCase.Client.buildRequest("GET");
            response = makeResponse('Unauthorized', 'Token is not active');

            exception = testCase.Client.buildError("fetchThing", response);

            testCase.verifyEqual(exception.message, 'Unauthorized: Token is not active');
        end

        function testOtherErrorWithoutTokenKeepsServerText(testCase)
            testCase.Client.buildRequest("GET");
            response = makeResponse('NotFound', 'no such bucket');

            exception = testCase.Client.buildError("fetchThing", response);

            testCase.verifyEqual(exception.message, 'NotFound: no such bucket');
        end
    end
end

function response = makeResponse(statusName, bodyText)
    response = matlab.net.http.ResponseMessage(...
        matlab.net.http.StatusCode(statusName), [], matlab.net.http.MessageBody(bodyText));
end
