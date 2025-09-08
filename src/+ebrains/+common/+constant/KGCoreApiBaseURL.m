function url = KGCoreApiBaseURL(serverOpts)
% KGCoreApiBaseURL - Base URL for KG core api

    arguments
        serverOpts.Server (1,1) string ...
            {mustBeMember(serverOpts.Server, ["prod", "preprod"])} = "prod"
    end

    if serverOpts.Server == "prod"
        url = "https://core.kg.ebrains.eu/v3";
    else
        url = "https://core.kg-ppd.ebrains.eu/v3";
    end
end
