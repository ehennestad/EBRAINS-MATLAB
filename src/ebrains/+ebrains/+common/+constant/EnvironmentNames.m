function environmentNames = EnvironmentNames()
%EnvironmentNames - Names of the EBRAINS environments the toolbox can use
%   environmentNames = ebrains.common.constant.EnvironmentNames() returns
%   a string row with the values of the Environment preference:
%       "prod" - The production environment.
%       "int"  - The integration environment.
%
%   See also ebrains.useEnvironment, ebrains.util.Preferences

    environmentNames = ["prod", "int"];
end
