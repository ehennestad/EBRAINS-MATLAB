function url = IamBaseUrl(options)
%IamBaseUrl - Base URL of the EBRAINS identity provider
%   URL = ebrains.common.constant.IamBaseUrl() returns the URL, with a
%   trailing slash, of the realm the token clients log in to, for the
%   environment of the Environment preference.
%
%   URL = ebrains.common.constant.IamBaseUrl(Environment=ENVIRONMENT) also
%   specifies the environment. ENVIRONMENT must be "prod" or "int".
%
%   See also ebrains.useEnvironment, ebrains.iam.OidcTokenClient

    arguments
        options.Environment (1,1) string {ebrains.internal.mustBeEnvironmentName} = ...
            ebrains.getpref("Environment")
    end

    REALM_PATH = "/auth/realms/hbp/";

    switch options.Environment
        case "prod"
            url = "https://iam.ebrains.eu" + REALM_PATH;
        case "int"
            url = "https://iam-int.ebrains.eu" + REALM_PATH;
        otherwise
            % Not reached: mustBeEnvironmentName accepts no other name.
    end
end
