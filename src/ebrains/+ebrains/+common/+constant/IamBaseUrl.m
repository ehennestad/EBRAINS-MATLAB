function url = IamBaseUrl(options)
%IamBaseUrl - Base URL of the EBRAINS identity provider
%   URL = ebrains.common.constant.IamBaseUrl() returns the URL, with a
%   trailing slash, of the realm the token clients log in to, for the
%   environment of the Environment preference.
%
%   URL = ebrains.common.constant.IamBaseUrl(Environment=ENVIRONMENT) also
%   specifies the environment. ENVIRONMENT must be "prod" or "int".
%
%   See also ebrains.useEnvironment, ebrains.common.enum.Environment,
%   ebrains.iam.OidcTokenClient

    arguments
        options.Environment (1,1) ebrains.common.enum.Environment = ...
            ebrains.getpref("Environment")
    end

    REALM_PATH = "/auth/realms/hbp/";

    url = "https://" + options.Environment.IamHost + REALM_PATH;
end
