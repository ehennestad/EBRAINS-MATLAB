classdef GetTokenExpirationTest < matlab.unittest.TestCase
    % GetTokenExpirationTest - Unit tests for ebrains.internal.get_token_expiration

    properties (Constant)
        ExpiryPosixTime = round(posixtime(datetime(2027, 1, 15, 10, 0, 0, TimeZone="UTC")))
    end

    methods (Test)
        function testReturnsExpiryAsLocalDatetime(testCase)
            token = ebrains.mocks.makeTestJwt(struct('exp', testCase.ExpiryPosixTime));

            expiration = ebrains.internal.get_token_expiration(char(token));

            % Compared as an instant rather than as a local wall-clock time,
            % since the CI runner's time zone is not this machine's; a
            % datetime constructed with TimeZone="local" reports the
            % resolved zone name, not the literal word "local".
            testCase.verifyEqual(posixtime(expiration), testCase.ExpiryPosixTime);
            testCase.verifyNotEmpty(expiration.TimeZone);
        end
    end
end
