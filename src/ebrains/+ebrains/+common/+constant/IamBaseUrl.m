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

    switch options.Environment
        case ebrains.common.enum.Environment.PROD
            url = "https://iam.ebrains.eu" + REALM_PATH;
        case ebrains.common.enum.Environment.INT
            url = "https://iam-int.ebrains.eu" + REALM_PATH;
        otherwise
            % Not reached: the enumeration has no other member.
    end
end
