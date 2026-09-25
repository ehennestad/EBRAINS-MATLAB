classdef HttpClientTest < matlab.unittest.TestCase
    % HttpClientTest - Unit tests for ebrains.common.internal.HttpClient
    %
    % Uses MockHttpClient, a minimal concrete subclass, so that no token is
    % needed and no request reaches a server.

    properties
        Client ebrains.mocks.MockHttpClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockHttpClient();
        end
    end

    methods (Test)
        %% Request building
        function testRequestUsesGivenMethod(testCase)
            request = testCase.Client.buildRequest("PATCH");
            testCase.verifyEqual(char(request.Method), 'PATCH');
        end

        function testRequestWithoutPayloadHasNoBody(testCase)
            request = testCase.Client.buildRequest("GET");
            testCase.verifyEmpty(request.Body);
        end

        function testJsonPayloadIsSentVerbatim(testCase)
            % JSON-LD keys such as "@id" are not valid MATLAB field names,
            % so the payload has to reach the wire without re-encoding.
            payload = '{"@id":"x","@type":["A"]}';
            request = testCase.Client.buildJsonRequest("POST", payload);
            testCase.Client.addResponse('OK', struct());

            testCase.Client.dispatch(request, matlab.net.URI("https://example.org/instances"));

            testCase.verifyEqual(testCase.Client.getRequestPayload(1), payload);
        end

        %% Error reporting
        function testErrorIdHoldsPrefixOperationAndStatus(testCase)
            response = makeResponse('NotFound', 'no such thing');
            exception = testCase.Client.buildError("fetchThing", response);
            testCase.verifyEqual(exception.identifier, 'EBRAINS:Test:fetchThing:NotFound');
        end

        function testErrorMessageHoldsStatusNameAndBodyText(testCase)
            response = makeResponse('NotFound', 'no such thing');
            exception = testCase.Client.buildError("fetchThing", response);
            testCase.verifyEqual(exception.message, 'NotFound: no such thing');
        end

        function testErrorMessageWithoutBodyIsStatusName(testCase)
            response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.NotFound);
            exception = testCase.Client.buildError("fetchThing", response);
            testCase.verifyEqual(exception.message, 'NotFound');
        end

        function testErrorMessageKeepsFormatCharacters(testCase)
            % "%" and "\" in the server's text must not be read as format
            % specifiers when the message is composed.
            serverText = '100% sure: C:\path\new';
            response = makeResponse('BadRequest', serverText);
            exception = testCase.Client.buildError("fetchThing", response);
            testCase.verifyEqual(exception.message, ['BadRequest: ', serverText]);
        end

        function testDescriptionReplacesBodyText(testCase)
            response = makeResponse('InternalServerError', 'stack trace');
            exception = testCase.Client.buildError("fetchThing", response, Description="server is down");
            testCase.verifyEqual(exception.message, 'InternalServerError: server is down');
        end

        function testThrowErrorThrowsWithIdentifier(testCase)
            response = makeResponse('Unauthorized', 'token expired');
            testCase.verifyError(@() testCase.Client.raiseError("fetchThing", response), ...
                'EBRAINS:Test:fetchThing:Unauthorized');
        end
    end
end

function response = makeResponse(statusName, bodyText)
    response = matlab.net.http.ResponseMessage(...
        matlab.net.http.StatusCode(statusName), [], matlab.net.http.MessageBody(bodyText));
end
