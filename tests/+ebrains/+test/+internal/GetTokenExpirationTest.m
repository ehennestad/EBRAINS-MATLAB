classdef GetTokenExpirationTest < matlab.unittest.TestCase
    % GetTokenExpirationTest - Unit tests for ebrains.internal.get_token_expiration

    methods (Test)
        function testReturnsExpiryAsLocalDatetime(testCase)
            expiryPosixTime = round(posixtime(datetime(2027, 1, 15, 10, 0, 0, TimeZone="UTC")));
            token = makeJwt(struct('exp', expiryPosixTime));

            expiration = ebrains.internal.get_token_expiration(char(token));

            % Compared as an instant rather than as a local wall-clock time,
            % since the CI runner's time zone is not this machine's; a
            % datetime constructed with TimeZone="local" reports the
            % resolved zone name, not the literal word "local".
            testCase.verifyEqual(posixtime(expiration), expiryPosixTime);
            testCase.verifyNotEmpty(expiration.TimeZone);
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
