function authenticate(mode, options, oidcOptions)
%AUTHENTICATE - Log in to EBRAINS with an OIDC authentication flow
%   AUTHENTICATE() obtains an access token for EBRAINS using the device
%   flow, which opens a browser page where you log in and grant access.
%   Nothing happens when the current token is still valid.
%
%   AUTHENTICATE(MODE) also specifies whether a valid token is reused.
%   MODE must be:
%       "default" - (default) Authenticate only when there is no active
%                   token.
%       "refresh" - Fetch or refresh the token even when one is active.
%
%   AUTHENTICATE(...,OAuthFlow=FLOW) also specifies the flow to use.
%   FLOW must be:
%       "DeviceFlow"            - (default) Log in interactively in the
%                                 browser.
%       "ClientCredentialsFlow" - Authenticate as a service with a client
%                                 id and secret, without user interaction.
%
%   AUTHENTICATE(...,OIDCClientID=ID) also specifies the OIDC client id
%   to authenticate as. The default is the client id of this toolbox.
%
%   AUTHENTICATE(...,OIDCClientSecret=SECRET) also specifies the client
%   secret. The client credentials flow needs both a client id and a
%   secret, and giving only one of the two is an error. The device flow
%   ignores the secret with a warning.
%
%   See also getTokenManager, ebrains.iam.enum.FlowType,
%   ebrains.iam.DeviceFlowTokenClient,
%   ebrains.iam.ClientCredentialsFlowTokenClient

    arguments
        mode (1,1) string {mustBeMember(mode, ["default", "refresh"])} = "default"
        options.OAuthFlow (1,1) ebrains.iam.enum.FlowType = "DeviceFlow"
        oidcOptions.OIDCClientID (1,1) string
        oidcOptions.OIDCClientSecret (1,1) string
    end

    % The INSTANCE method of each client takes its credentials positionally,
    % so they are named here one by one. Forwarding the values of the
    % options struct would leave the meaning of each to the order of its
    % fields, and a client id and a secret that swap places are a login
    % attempt with the secret as the client id.
    hasClientId = isfield(oidcOptions, "OIDCClientID");
    hasClientSecret = isfield(oidcOptions, "OIDCClientSecret");

    switch string(options.OAuthFlow)
        case "DeviceFlow"
            if hasClientSecret
                warning("EBRAINS:authenticate:SecretNotSupported", ...
                   "The Device Flow does not require a OIDC client secret")
            end
            if hasClientId
                tokenClient = ebrains.iam.DeviceFlowTokenClient.instance(...
                    oidcOptions.OIDCClientID);
            else
                tokenClient = ebrains.iam.DeviceFlowTokenClient.instance();
            end

        case "ClientCredentialsFlow"
            % One of the two on its own would authenticate as a client with
            % an empty id or an empty secret, which the identity provider
            % refuses with an error that does not name the missing half.
            if hasClientId ~= hasClientSecret
                error("EBRAINS:authenticate:IncompleteCredentials", ...
                    "The Client Credentials Flow needs both a OIDC client " + ...
                    "id and a OIDC client secret. Give both, or neither to " + ...
                    "reuse the credentials of the current token client.")
            end
            if hasClientId
                tokenClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance(...
                    oidcOptions.OIDCClientID, oidcOptions.OIDCClientSecret);
            else
                tokenClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance();
            end

        otherwise
            error('EBRAINS:authenticate:UnsupportedFlow', ...
                'Unsupported flow type: "%s"', string(options.OAuthFlow))
    end

    if mode == "refresh" || ~tokenClient.hasActiveToken()
        tokenClient.authenticate()
    end
end
