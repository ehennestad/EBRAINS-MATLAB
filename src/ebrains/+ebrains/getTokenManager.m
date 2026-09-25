function tokenManager = getTokenManager(options)
%getTokenManager - Get the token client that holds the EBRAINS token
%   tokenManager = ebrains.getTokenManager() returns the token client to
%   use for authenticated requests. The client credentials client is
%   returned when it can supply a valid access token. Otherwise the device
%   flow client is returned, after logging in through the browser when it
%   has no active token.
%
%   tokenManager = ebrains.getTokenManager(Interactive=false) never logs
%   in. It returns the client credentials client when it can supply a
%   valid access token, the device flow client when it has an active
%   token, and [] otherwise. The API clients call it this way unless the
%   AutoLogin preference is true, so that a request is sent without a
%   token when none is available.
%
%   tokenManager = ebrains.getTokenManager(AutoRenew=TF) also specifies
%   whether an expired device flow token is renewed with its refresh
%   token before a login is considered. The renewal needs no user
%   interaction. The default is the AutoRenew preference (see
%   ebrains.getpref).
%
%   A token given through the EBRAINS_TOKEN environment variable is held
%   by the client credentials client, which cannot renew it. Once such a
%   token has expired the device flow client is used instead, so that
%   logging in with ebrains.authenticate takes effect.
%
%   Set the environment variable
%   EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW to "true" to never
%   use the device flow client. When the client credentials client cannot
%   supply a token, ebrains.getTokenManager then raises an error, also
%   with Interactive=false: a job that forces this flow is meant to
%   authenticate with its credentials, and a request sent without a token
%   would fail with advice to log in through the device flow instead.
%
%   See also authenticate, ebrains.getpref, ebrains.iam.OidcTokenClient,
%   ebrains.iam.DeviceFlowTokenClient,
%   ebrains.iam.ClientCredentialsFlowTokenClient

    arguments
        options.Interactive (1,1) logical = true
        options.AutoRenew (1,1) logical = ebrains.getpref("AutoRenew")
    end

    tokenClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance();
    if tokenClient.canProvideToken()
        tokenManager = tokenClient;
        return
    end

    forceClientCredentialsFlow = getenv('EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW');
    if strcmpi(forceClientCredentialsFlow, "true")
        error(...
            'EBRAINS:GetTokenManager:Unauthenticated', ...
            ['Client Credentials token manager does not have an active access token. ', ...
            'Please run ebrains.authenticate using "Client Credentials" flow type and try again.'])
    end

    % Fall back to use DeviceFlowTokenClient
    tokenManager = ebrains.iam.DeviceFlowTokenClient.instance();

    % Renewing before hasActiveToken below means a token that is renewed
    % raises no warning that it has expired.
    if options.AutoRenew
        tokenManager.tryRenewToken();
    end

    if ~tokenManager.hasActiveToken()
        if ~options.Interactive
            tokenManager = [];
            return
        end
        tokenManager.authenticate()
    end

    % If token manager does not have a valid token after refresh, we throw error
    if ~tokenManager.hasActiveToken()
        error(...
            'EBRAINS:GetTokenManager:TokenManagerNotFound', ...
            ['Did not find a token manager with an active access token. ', ...
            'Please run ebrains.authenticate and try again'])
    end
end
