function mustBeEnvironmentName(environment)
%mustBeEnvironmentName - Validate that a value names an EBRAINS environment
%   ebrains.internal.mustBeEnvironmentName(environment) raises
%   EBRAINS:Common:UnknownEnvironment unless environment is one of the
%   names returned by ebrains.common.constant.EnvironmentNames.
%
%   See also ebrains.common.constant.EnvironmentNames

    environmentNames = ebrains.common.constant.EnvironmentNames();

    isEnvironmentName = (ischar(environment) || isStringScalar(environment)) ...
        && ismember(environment, environmentNames);
    if ~isEnvironmentName
        error("EBRAINS:Common:UnknownEnvironment", ...
            "The environment must be one of: %s.", ...
            strjoin("""" + environmentNames + """", ", "))
    end
end
