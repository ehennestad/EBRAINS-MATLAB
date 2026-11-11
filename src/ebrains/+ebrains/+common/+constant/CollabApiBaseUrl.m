function url = CollabApiBaseUrl(options)
%CollabApiBaseUrl - Base URL of the EBRAINS Collaboratory REST API
%   URL = ebrains.common.constant.CollabApiBaseUrl() returns the base
%   URL, with a trailing slash, that the Collaboratory API client
%   prepends to its endpoint paths, for the environment of the
%   Environment preference.
%
%   URL = ebrains.common.constant.CollabApiBaseUrl(Environment=ENVIRONMENT)
%   also specifies the environment. ENVIRONMENT must be "prod" or "int".
%
%   See also CollabBaseUrl, ebrains.useEnvironment,
%   ebrains.common.enum.Environment, ebrains.collab.api.CollabsClient

    arguments
        options.Environment (1,1) ebrains.common.enum.Environment = ...
            ebrains.getpref("Environment")
    end

    API_PATH = "/rest/v1/";

    url = ebrains.common.constant.CollabBaseUrl(Environment=options.Environment) + API_PATH;
end
