classdef TokenLiveTest < matlab.unittest.TestCase
    % TokenLiveTest - Live checks of JWT decoding on a real EBRAINS token
    %
    % Decodes the access token of the authenticated session with
    % ebrains.internal.decode_jwt and get_token_expiration. Their unit tests
    % only see tokens built by ebrains.mocks.makeTestJwt, so a payload from
    % the real identity provider that the decoder cannot handle would go
    % unnoticed there.
    %
    % Tagged "LiveIntegration"; see BucketLiveTest.

    properties (Constant)
        % Issuer claim of tokens from the EBRAINS identity provider; the
        % realm URL without the trailing slash the token clients use.
        Issuer = "https://iam.ebrains.eu/auth/realms/hbp"

        % Largest accepted difference between the expiry decoded from the
        % token and the expiry the token client derives from the expires_in
        % field of the token response. The two come from different clocks
        % at slightly different moments, so they differ by the request
        % latency and the clock offset to the identity provider, whereas a
        % time zone error shifts the decoded expiry by 30 minutes or more.
        ExpiryTolerance = minutes(2)
    end

    methods (Test, TestTags = {'LiveIntegration'})
        function testDecodesIssuerAndExpiryClaims(testCase)
            token = ebrains.getTokenManager().AccessToken;

            payload = ebrains.internal.decode_jwt(char(token));

            testCase.assertThat(payload, matlab.unittest.constraints.HasField("iss"));
            testCase.verifyEqual(string(payload.iss), testCase.Issuer);

            testCase.assertThat(payload, matlab.unittest.constraints.HasField("exp"));
            testCase.verifyClass(payload.exp, "double");
            testCase.verifySize(payload.exp, [1 1]);
        end

        function testExpiryIsInTheFuture(testCase)
            % Reading AccessToken refreshes an expired token, so the token
            % it returns must still be valid.
            token = ebrains.getTokenManager().AccessToken;

            expiration = ebrains.internal.get_token_expiration(char(token));

            testCase.verifyGreaterThan(expiration, datetime("now", TimeZone="local"));
        end

        function testExpiryMatchesTokenResponseLifetime(testCase)
            % A token read from EBRAINS_TOKEN has its expiry decoded by the
            % client itself, which would make this comparison circular.
            testCase.assumeFalse(isenv("EBRAINS_TOKEN") && strlength(getenv("EBRAINS_TOKEN")) > 0, ...
                "The token client decoded its expiry from EBRAINS_TOKEN rather than a token response.")

            tokenManager = ebrains.getTokenManager();
            token = tokenManager.AccessToken;
            clientTimeLeft = tokenManager.ExpiresIn;

            decodedTimeLeft = ebrains.internal.get_token_expiration(char(token)) ...
                - datetime("now", TimeZone="local");

            testCase.verifyLessThanOrEqual(abs(decodedTimeLeft - clientTimeLeft), testCase.ExpiryTolerance);
        end
    end
end
