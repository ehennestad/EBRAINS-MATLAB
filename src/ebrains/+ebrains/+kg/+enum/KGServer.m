classdef KGServer
%KGServer - Knowledge Graph servers a request can be sent to
%   KGServer enumerates the deployments of the EBRAINS Knowledge Graph
%   (KG). The KG API clients accept a member, or its name as text, in
%   their Server option.
%
%   KGServer members:
%       PROD    - The production server
%       PREPROD - The pre-production server, for testing
%
%   KGServer properties:
%       Name - Short lowercase name of the server
%
%   See also ebrains.kg.api.InstancesClient,
%   ebrains.common.constant.KGCoreApiBaseURL

    enumeration
        PROD("prod")
        PREPROD("preprod")
    end

    properties
        Name  % Short lowercase name of the server
    end
    methods
        function obj = KGServer(name)
            obj.Name = name;
        end
    end
end
