classdef DeviceFlowTokenClientTest < ebrains.test.iam.TokenClientTestCase
    % DeviceFlowTokenClientTest - Unit tests for ebrains.iam.DeviceFlowTokenClient
    %
    % The login is driven through the mock, which answers the device
    % authorization and every poll of the token endpoint, and records the
    % browser page and the dialog stages. The singleton lifecycle is tested
    % through the real class, which needs no network until a login starts.

    methods (Test)
        %% Login
        function testLoginSucceedsOnFirstPoll(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('OK', testCase.makeTokenResponse("access-1"));

            client.authenticate();

            testCase.verifyTrue(client.hasActiveToken());
            testCase.verifyEqual(client.AccessToken, "access-1");
            testCase.verifyEqual(client.DeviceAuthorizationRequestCount, 1);
            testCase.verifyEqual(client.PollCount, 1);
            testCase.verifyEqual(client.OpenedUrls, string(client.DeviceResponse.verification_uri_complete));
            testCase.verifyEqual(client.Dialog.Calls, ["showRedirecting", "showWaiting", "showSuccess", "close"]);
        end

        function testLoginKeepsPollingWhileAuthorizationPending(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('BadRequest', struct('error', 'authorization_pending'));
            client.addPollResponse('BadRequest', struct('error', 'authorization_pending'));
            client.addPollResponse('OK', testCase.makeTokenResponse());

            client.authenticate();

            testCase.verifyEqual(client.PollCount, 3);
            testCase.verifyTrue(client.hasActiveToken());
        end

        function testLoginSlowsDownWhenAsked(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('BadRequest', struct('error', 'slow_down'));
            client.addPollResponse('OK', testCase.makeTokenResponse());

            client.authenticate();

            testCase.verifyEqual(client.PollCount, 2);
            testCase.verifyTrue(client.hasActiveToken());
        end

        %% Failures
        function testExpiredDeviceCodeFails(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('BadRequest', struct('error', 'expired_token'));

            testCase.verifyError(@() client.authenticate(), 'EBRAINS:DeviceFlow:DeviceCodeExpired');

            testCase.verifyEqual(client.ErrorDialogs(1).Title, "Authentication Failed.");
            testCase.verifyEqual(client.Dialog.Calls(end), "close");
            testCase.verifyFalse(client.hasActiveToken());
        end

        function testAccessDeniedByUserFails(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient("my-client");
            client.addPollResponse('BadRequest', struct('error', 'access_denied', ...
                'error_description', 'The end user denied the authorization request'));

            testCase.verifyError(@() client.authenticate(), 'EBRAINS:DeviceFlow:AccessDenied');

            testCase.verifySubstring(client.ErrorDialogs(1).Message, "my-client");
        end

        function testOtherBadRequestReportsProviderMessage(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('BadRequest', struct('error', 'invalid_grant', ...
                'error_description', 'Device code not valid'));

            testCase.verifyError(@() client.authenticate(), 'EBRAINS:DeviceFlow:BadRequest');

            testCase.verifyEqual(client.ErrorDialogs(1).Title, "invalid_grant");
            testCase.verifyEqual(client.ErrorDialogs(1).Message, "Device code not valid");
        end

        function testAccessDeniedForOtherReasonIsABadRequest(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('BadRequest', struct('error', 'access_denied', ...
                'error_description', 'Client is disabled'));

            testCase.verifyError(@() client.authenticate(), 'EBRAINS:DeviceFlow:BadRequest');
        end

        function testUnexpectedStatusFails(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.addPollResponse('InternalServerError', struct('detail', 'down'));

            testCase.verifyError(@() client.authenticate(), 'EBRAINS:DeviceFlow:UnexpectedHTTPStatus');

            testCase.verifySubstring(client.ErrorDialogs(1).Message, "Unexpected HTTP status");
        end

        function testLoginTimesOutWhenWindowHasPassed(testCase)
            client = ebrains.mocks.MockDeviceFlowTokenClient();
            client.DeviceResponse.expires_in = 0;

            testCase.verifyError(@() client.authenticate(), 'EBRAINS:DeviceFlow:Timeout');

            testCase.verifyEqual(client.PollCount, 0);
            testCase.verifyEqual(client.Dialog.Calls(end), "close");
        end

        %% Singleton lifecycle
        function testInstanceUsesTheDefaultClientId(testCase)
            client = ebrains.iam.DeviceFlowTokenClient.instance();

            testCase.verifyEqual(client.ClientId, ebrains.common.constant.OIDCClientID());
            testCase.verifySameHandle(ebrains.iam.DeviceFlowTokenClient.instance(), client);
        end

        function testInstanceWithOtherClientIdReplaces(testCase)
            first = ebrains.iam.DeviceFlowTokenClient.instance();

            second = ebrains.iam.DeviceFlowTokenClient.instance("other-client");

            testCase.verifyEqual(second.ClientId, "other-client");
            testCase.verifyFalse(isvalid(first));
        end

        function testResetDeletesTheInstance(testCase)
            first = ebrains.iam.DeviceFlowTokenClient.instance();

            ebrains.iam.DeviceFlowTokenClient.reset();

            testCase.verifyFalse(isvalid(first));
            testCase.verifyNotSameHandle(ebrains.iam.DeviceFlowTokenClient.instance(), first);
        end
    end
end
