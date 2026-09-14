function apiUri = buildApiUri(baseUrl, pathSegments, requiredParams, optionalParams)
% buildApiUri - Build the URI of an API endpoint from its parts
%
% Syntax:
%   apiUri = ebrains.common.internal.buildApiUri(baseUrl, pathSegments)
%   apiUri = ebrains.common.internal.buildApiUri(baseUrl, pathSegments, ...
%       requiredParams, optionalParams)
%
% Input Arguments:
%   baseUrl        - Base URL of the service, with or without a trailing
%                    slash.
%   pathSegments   - String array with one element per path segment below
%                    the base URL. Each segment is percent-encoded on its
%                    own, so a segment may hold characters such as "/" or
%                    " " (the name of an object in a bucket, for example).
%   requiredParams - Struct with one field per query parameter.
%   optionalParams - Struct with one field per query parameter.
%
% Output Arguments:
%   apiUri - matlab.net.URI of the endpoint.

    arguments
        baseUrl (1,1) string
        pathSegments (1,:) string
        requiredParams struct = struct.empty
        optionalParams struct = struct.empty
    end

    apiUri = matlab.net.URI(baseUrl);

    % A base URL with a trailing slash ends in an empty path segment, which
    % would otherwise leave a double slash before the endpoint path.
    basePath = apiUri.Path;
    if ~isempty(basePath) && basePath(end) == ""
        basePath(end) = [];
    end
    apiUri.Path = [basePath, pathSegments];

    apiUri.Query = [ ...
        toQueryParameters(requiredParams), ...
        toQueryParameters(optionalParams) ...
        ];
end

function queryParameters = toQueryParameters(params)
% toQueryParameters - Query parameters of a struct, none for a struct without fields

    if isempty(params) || isempty(fieldnames(params))
        queryParameters = matlab.net.QueryParameter.empty(1, 0);
    else
        queryParameters = matlab.net.QueryParameter(params);
    end
end
