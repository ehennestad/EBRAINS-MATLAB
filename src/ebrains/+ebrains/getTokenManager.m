function tokenManager = getTokenManager()
%getTokenManager - Get the token client that holds the EBRAINS token
%   tokenManager = getTokenManager() returns the token client to use for
%   authenticated requests. The client credentials client is returned
%   when it can supply a valid access token. Otherwise the device flow
%   client is returned, after logging in through the browser when it has
%   no active token.
%
%   A token given through the EBRAINS_TOKEN environment variable is held
%   by the client credentials client, which cannot renew it. Once such a
%   token has expired the device flow client is used instead, so that
%   logging in with ebrains.authenticate takes effect.
%
%   Set the environment variable
%   EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW to "true" to raise
%   an error instead of falling back to the device flow.
%
%   See also authenticate, ebrains.iam.OidcTokenClient,
%   ebrains.iam.DeviceFlowTokenClient,
%   ebrains.iam.ClientCredentialsFlowTokenClient

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
    if ~tokenManager.hasActiveToken()
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
