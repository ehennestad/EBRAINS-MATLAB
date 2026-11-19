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

    url = "https://" + options.Environment.CollabHost;
end
