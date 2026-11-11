function useEnvironment(environment)
%useEnvironment - Select the EBRAINS environment for this MATLAB session
%   ebrains.useEnvironment(ENVIRONMENT) sets the Environment preference
%   until MATLAB closes, leaving the saved value as it is. ENVIRONMENT
%   is a member of ebrains.common.enum.Environment or its name:
%       "prod" - The production environment.
%       "int"  - The integration environment.
%
%   It is the same as
%   ebrains.setpref(Environment=ENVIRONMENT, Scope="temporary"). The help
%   of ebrains.util.Preferences lists what the preference selects.
%
%   The token clients keep one login per environment, so a login made in
%   one environment is still there after switching to the other and back.
%
%   Example:
%       ebrains.useEnvironment("int")
%       ebrains.login()
%       ebrains.useEnvironment("prod")
%
%   See also ebrains.setpref, ebrains.util.Preferences, ebrains.login,
%   ebrains.common.enum.Environment

    arguments
        environment (1,1) ebrains.common.enum.Environment
    end

    ebrains.setpref(Environment=environment, Scope="temporary")
end
