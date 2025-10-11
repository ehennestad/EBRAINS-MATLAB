function authenticate(mode, options, oidcOptions)
% authenticate - Authenticate with EBRAINS using selected OIDC auth flow type.

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

    if ~tokenClient.hasActiveToken() || mode == "refresh"
        tokenClient.refreshToken()
    end
end
