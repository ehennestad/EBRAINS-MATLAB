classdef DecodeJwtTest < matlab.unittest.TestCase
    % DecodeJwtTest - Unit tests for ebrains.internal.decode_jwt

    properties (Constant)
        % Claims put into a token and expected back out of it
        Claims = struct('sub', 'user123', 'exp', 1234567890)
        % Long enough for its base64 form to hold "+" or "/", the
        % characters the base64url substitution in decode_jwt exists for
        LongNote = repmat('x', 1, 40)
    end

    methods (Test)
        function testDecodesPayloadClaims(testCase)
            token = ebrains.mocks.makeTestJwt(testCase.Claims);

            payload = ebrains.internal.decode_jwt(char(token));

            testCase.verifyEqual(payload, testCase.Claims);
        end

        function testAcceptsBase64UrlCharactersInPayload(testCase)
            token = ebrains.mocks.makeTestJwt(struct('note', testCase.LongNote));

            payload = ebrains.internal.decode_jwt(char(token));

            testCase.verifyEqual(payload.note, testCase.LongNote);
        end

        function testMissingPayloadSegmentErrors(testCase)
            % decode_jwt splits on "." and indexes the second part directly,
            % so a token without one raises a generic indexing error rather
            % than a message about a malformed token.
            testCase.verifyError(@() ebrains.internal.decode_jwt('onlyonepart'), ?MException);
        end
    end
end
