function url = CollabApiBaseUrl()
%CollabApiBaseUrl - Base URL of the EBRAINS Collaboratory REST API
%   URL = ebrains.common.constant.CollabApiBaseUrl() returns the base
%   URL, with a trailing slash, that the Collaboratory API client
%   prepends to its endpoint paths.
%
%   See also CollabBaseUrl, ebrains.collab.api.CollabsClient

    url = "https://wiki.ebrains.eu/rest/v1/";
end
