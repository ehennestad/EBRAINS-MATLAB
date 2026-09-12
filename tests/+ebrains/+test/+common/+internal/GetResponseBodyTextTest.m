classdef GetResponseBodyTextTest < matlab.unittest.TestCase
    % GetResponseBodyTextTest - Unit tests for ebrains.common.internal.getResponseBodyText

    methods (Test)
        function testTextBodyIsReturnedAsIs(testCase)
            response = makeResponse(matlab.net.http.MessageBody('Instance not found'));
            testCase.verifyEqual(ebrains.common.internal.getResponseBodyText(response), "Instance not found");
        end

        function testStringBodyIsReturnedAsIs(testCase)
            response = makeResponse(matlab.net.http.MessageBody("no access"));
            testCase.verifyEqual(ebrains.common.internal.getResponseBodyText(response), "no access");
        end

        function testStructBodyIsEncodedAsJson(testCase)
            response = makeResponse(matlab.net.http.MessageBody(struct('error', 'forbidden')));
            testCase.verifyEqual(ebrains.common.internal.getResponseBodyText(response), "{""error"":""forbidden""}");
        end

        function testRawBytesAreDecodedAsText(testCase)
            response = makeResponse(matlab.net.http.MessageBody(uint8('raw text')'));
            testCase.verifyEqual(ebrains.common.internal.getResponseBodyText(response), "raw text");
        end

        function testEmptyBodyGivesEmptyString(testCase)
            response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.NotFound);
            testCase.verifyEqual(ebrains.common.internal.getResponseBodyText(response), "");
        end

        function testEmptyDataGivesEmptyString(testCase)
            response = makeResponse(matlab.net.http.MessageBody(''));
            testCase.verifyEqual(ebrains.common.internal.getResponseBodyText(response), "");
        end
    end
end

function response = makeResponse(body)
    response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.NotFound, [], body);
end
