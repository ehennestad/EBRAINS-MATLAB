function logout()
%LOGOUT - Log out of EBRAINS by removing the tokens held in this session
%   LOGOUT() deletes the token clients of the device flow and the client
%   credentials flow, together with the access tokens, refresh tokens and
%   client credentials they hold. Requests are then sent without a token,
%   or open a login when the AutoLogin preference is true, until you log
%   in again with ebrains.login.
%
%   The tokens are only removed from MATLAB. They are not revoked at the
%   EBRAINS identity provider, so a copy of an access token stays valid
%   until it expires.
%
%   A token given through the EBRAINS_TOKEN environment variable is
%   loaded again by the next request, and LOGOUT warns when the variable
%   is set. Run unsetenv("EBRAINS_TOKEN") to stop using it.
%
%   See also login, getTokenManager

    ebrains.iam.OidcTokenClient.resetAll()

    if isenv("EBRAINS_TOKEN") && strlength(getenv("EBRAINS_TOKEN")) > 0
        warning("EBRAINS:logout:EnvironmentTokenSet", ...
            "The EBRAINS_TOKEN environment variable is set, and the next " + ...
            "request will log in again with its token. Run " + ...
            "unsetenv(""EBRAINS_TOKEN"") to stop using it.")
    end
end
