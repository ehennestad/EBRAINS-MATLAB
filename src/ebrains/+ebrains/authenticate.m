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
%   secret. The device flow ignores the secret with a warning.
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

    switch string(options.OAuthFlow)
        case "DeviceFlow"
            if isfield(oidcOptions, "OIDCClientSecret")
                warning("EBRAINS:authenticate:SecretNotSupported", ...
                   "The Device Flow does not require a OIDC client secret")
                oidcOptions = rmfield(oidcOptions, "OIDCClientSecret");
            end
            nvPairs = struct2cell(oidcOptions);
            tokenClient = ebrains.iam.DeviceFlowTokenClient.instance(nvPairs{:});

        case "ClientCredentialsFlow"
            nvPairs = struct2cell(oidcOptions);
            tokenClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance(nvPairs{:});

        otherwise
            error('Unsupported flow type: "%s"', string(options.OAuthFlow))
    end

    if mode == "refresh" || ~tokenClient.hasActiveToken()
        tokenClient.authenticate()
    end
end
