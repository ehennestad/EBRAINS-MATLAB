function url = CollabBaseUrl(options)
%CollabBaseUrl - Base URL of the EBRAINS Collaboratory website
%   URL = ebrains.common.constant.CollabBaseUrl() returns the URL of the
%   Collaboratory wiki, without a trailing slash, for the environment of
%   the Environment preference.
%
%   URL = ebrains.common.constant.CollabBaseUrl(Environment=ENVIRONMENT)
%   also specifies the environment. ENVIRONMENT must be "prod" or "int".
%
%   See also CollabApiBaseUrl, ebrains.useEnvironment

    arguments
        options.Environment (1,1) string {ebrains.internal.mustBeEnvironmentName} = ...
            ebrains.getpref("Environment")
    end

    switch options.Environment
        case "prod"
            url = "https://wiki.ebrains.eu";
        case "int"
            url = "https://wiki-int.ebrains.eu";
        otherwise
            % Not reached: mustBeEnvironmentName accepts no other name.
    end
end
