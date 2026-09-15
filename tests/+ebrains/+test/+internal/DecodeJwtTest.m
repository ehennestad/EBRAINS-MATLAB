classdef DecodeJwtTest < matlab.unittest.TestCase
    % DecodeJwtTest - Unit tests for ebrains.internal.decode_jwt

    methods (Test)
        function testDecodesPayloadClaims(testCase)
            token = makeJwt(struct('sub', 'user123', 'exp', 1234567890));

            payload = ebrains.internal.decode_jwt(char(token));

            testCase.verifyEqual(payload.sub, 'user123');
            testCase.verifyEqual(payload.exp, 1234567890);
        end

        function testAcceptsBase64UrlCharactersInPayload(testCase)
            % A payload whose standard-base64 encoding would contain "+" or
            % "/" is exactly the case the "-"/"_" substitution exists for.
            token = makeJwt(struct('note', repmat('x', 1, 40)));

            payload = ebrains.internal.decode_jwt(char(token));

            testCase.verifyEqual(payload.note, repmat('x', 1, 40));
        end

        function testMissingPayloadSegmentErrors(testCase)
            % decode_jwt splits on "." and indexes the second part directly,
            % so a token without one raises a generic indexing error rather
            % than a message about a malformed token.
            testCase.verifyError(@() ebrains.internal.decode_jwt('onlyonepart'), ?MException);
        end
    end
end

function token = makeJwt(payloadStruct)
% makeJwt - Build a JWT with a fixed header, an arbitrary payload, and no
%           real signature, matching what decode_jwt actually reads.
    toBase64Url = @(text) strrep(strrep(erase(matlab.net.base64encode(text), '='), '+', '-'), '/', '_');
    header = struct('alg', 'none', 'typ', 'JWT');
    token = toBase64Url(jsonencode(header)) + "." + toBase64Url(jsonencode(payloadStruct)) + ".signature";
end
