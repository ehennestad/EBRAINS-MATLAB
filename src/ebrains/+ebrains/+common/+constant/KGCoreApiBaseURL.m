function url = KGCoreApiBaseURL(serverOpts)
%KGCoreApiBaseURL - Base URL of the EBRAINS Knowledge Graph Core API
%   URL = ebrains.common.constant.KGCoreApiBaseURL() returns the base URL
%   of the KG Core API on the production server, without a trailing
%   slash.
%
%   URL = ebrains.common.constant.KGCoreApiBaseURL(Server=SERVER) also
%   specifies the server. SERVER must be:
%       "prod"    - (default) The production server.
%       "preprod" - The pre-production server.
%
%   See also ebrains.kg.enum.KGServer, ebrains.kg.api.base.BaseClient

    arguments
        serverOpts.Server (1,1) ebrains.kg.enum.KGServer = "prod"
    end

    if serverOpts.Server == "PROD"
        url = "https://core.kg.ebrains.eu/v3";
    elseif serverOpts.Server == "PREPROD"
        url = "https://core.kg-ppd.ebrains.eu/v3";
    else
        error('EBRAINS:Common:UnsupportedServer', ...
            'Unsupported server option: %s', string(serverOpts.Server))
    end
end
