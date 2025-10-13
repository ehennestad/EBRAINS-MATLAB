function tokenManager = getTokenManager()
% getTokenManager - Get a token manager

    % First we check ClientCredentialsFlowTokenClient
    tokenClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance();
    if tokenClient.canAuthenticate()
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
