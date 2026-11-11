function url = CollabBaseUrl(options)
%CollabBaseUrl - Base URL of the EBRAINS Collaboratory website
%   URL = ebrains.common.constant.CollabBaseUrl() returns the URL of the
%   Collaboratory wiki, without a trailing slash, for the environment of
%   the Environment preference.
%
%   URL = ebrains.common.constant.CollabBaseUrl(Environment=ENVIRONMENT)
%   also specifies the environment. ENVIRONMENT must be "prod" or "int".
%
%   See also CollabApiBaseUrl, ebrains.useEnvironment,
%   ebrains.common.enum.Environment

    arguments
        options.Environment (1,1) ebrains.common.enum.Environment = ...
            ebrains.getpref("Environment")
    end

    switch options.Environment
        case ebrains.common.enum.Environment.PROD
            url = "https://wiki.ebrains.eu";
        case ebrains.common.enum.Environment.INT
            url = "https://wiki-int.ebrains.eu";
        otherwise
            % Not reached: the enumeration has no other member.
    end
end
