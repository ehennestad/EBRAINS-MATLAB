classdef Environment
%Environment - EBRAINS environments the toolbox can work in
%   Environment enumerates the deployments of the EBRAINS services that
%   the Environment preference selects between. Functions that take an
%   environment accept a member, or its name as text.
%
%   Environment members:
%       PROD - The production environment
%       INT  - The integration environment, for testing
%
%   Environment properties:
%       Name - Short lowercase name of the environment
%
%   See also ebrains.useEnvironment, ebrains.util.Preferences,
%   ebrains.common.constant.IamBaseUrl,
%   ebrains.common.constant.CollabBaseUrl

    enumeration
        PROD("prod")
        INT("int")
    end

    properties
        Name (1,1) string  % Short lowercase name of the environment
    end

    methods
        function obj = Environment(name)
            obj.Name = name;
        end
    end
end
