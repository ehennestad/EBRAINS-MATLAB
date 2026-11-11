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

    switch options.Environment
        case ebrains.common.enum.Environment.PROD
            url = "https://data-proxy.ebrains.eu" + API_PATH;
        case ebrains.common.enum.Environment.INT
            url = "https://data-proxy-int.ebrains.eu" + API_PATH;
        otherwise
            % Not reached: the enumeration has no other member.
    end
end
