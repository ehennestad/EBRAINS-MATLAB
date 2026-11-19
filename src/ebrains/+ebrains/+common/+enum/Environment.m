classdef Environment
%Environment - EBRAINS environments the toolbox can work in
%   Environment enumerates the deployments of the EBRAINS services that
%   the Environment preference selects between, and holds the hosts of
%   the services of each. Functions that take an environment accept a
%   member, or its name as text.
%
%   Environment members:
%       PROD - The production environment
%       INT  - The integration environment, for testing
%
%   Environment properties:
%       Name          - Short lowercase name of the environment
%       IamHost       - Host of the identity provider
%       CollabHost    - Host of the Collaboratory
%       DataProxyHost - Host of the Data Proxy
%
%   See also ebrains.useEnvironment, ebrains.util.Preferences,
%   ebrains.common.constant.IamBaseUrl,
%   ebrains.common.constant.CollabBaseUrl,
%   ebrains.common.constant.DataProxyApiBaseUrl

    % The Name of a member must be its member name in lowercase. The
    % Environment setting holds the Name (see ebrains.util.Preferences),
    % and ebrains.getpref converts that text back to a member, which
    % MATLAB matches against the member names and not against Name.
    enumeration
        PROD("prod", "iam.ebrains.eu", "wiki.ebrains.eu", "data-proxy.ebrains.eu")
        INT("int", "iam-int.ebrains.eu", "wiki-int.ebrains.eu", "data-proxy-int.ebrains.eu")
    end

    properties
        Name (1,1) string           % Short lowercase name of the environment
        IamHost (1,1) string        % Host of the identity provider
        CollabHost (1,1) string     % Host of the Collaboratory
        DataProxyHost (1,1) string  % Host of the Data Proxy
    end

    methods
        function obj = Environment(name, iamHost, collabHost, dataProxyHost)
            obj.Name = name;
            obj.IamHost = iamHost;
            obj.CollabHost = collabHost;
            obj.DataProxyHost = dataProxyHost;
        end
    end
end
