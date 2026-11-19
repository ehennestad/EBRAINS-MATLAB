function url = DataProxyApiBaseUrl(options)
%DataProxyApiBaseUrl - Base URL of the EBRAINS Data Proxy API
%   URL = ebrains.common.constant.DataProxyApiBaseUrl() returns the base
%   URL, with a trailing slash, that the bucket client prepends to its
%   endpoint paths, for the environment of the Environment preference.
%
%   URL = ebrains.common.constant.DataProxyApiBaseUrl(Environment=ENVIRONMENT)
%   also specifies the environment. ENVIRONMENT must be "prod" or "int".
%
%   See also ebrains.useEnvironment, ebrains.common.enum.Environment,
%   ebrains.bucket.api.BucketsClient

    arguments
        options.Environment (1,1) ebrains.common.enum.Environment = ...
            ebrains.getpref("Environment")
    end

    API_PATH = "/api/v1/";

    url = "https://" + options.Environment.DataProxyHost + API_PATH;
end
