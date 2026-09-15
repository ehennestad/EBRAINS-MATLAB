function url = DataProxyApiBaseUrl()
%DataProxyApiBaseUrl - Base URL of the EBRAINS Data Proxy API
%   URL = DataProxyApiBaseUrl() returns the base URL, with a trailing
%   slash, that the bucket client prepends to its endpoint paths.
%
%   See also ebrains.bucket.api.BucketsClient

    url = "https://data-proxy.ebrains.eu/api/v1/";
end
