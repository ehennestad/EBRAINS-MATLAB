function url = KGCoreApiBaseURL(serverOpts)
% KGCoreApiBaseURL - Base URL for KG core api

    arguments
        serverOpts.Server (1,1) ebrains.kg.enum.KGServer = "prod"
    end

    if serverOpts.Server == "PROD"
        url = "https://core.kg.ebrains.eu/v3";
    elseif serverOpts.Server == "PREPROD"
        url = "https://core.kg-ppd.ebrains.eu/v3";
    else
        error('Unsupported server option: %s', serverOpts.Server)
    end
end
