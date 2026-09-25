function preferences = setpref(preferenceValues, options)
%setpref - Set preferences of the EBRAINS Services Toolbox
%   ebrains.setpref(Name=Value) sets one or more preferences and saves
%   them, so that they also apply in later MATLAB sessions. The names
%   are those of the properties of ebrains.util.Preferences, whose help
%   describes each preference.
%
%   ebrains.setpref(...,Scope=SCOPE) also specifies how long the values
%   apply. SCOPE must be:
%       "personal"  - (default) Save the values for later sessions.
%       "temporary" - Apply the values until MATLAB closes, leaving the
%                     saved ones as they are. A temporary value takes
%                     precedence over a saved one, so use this to try a
%                     preference without changing what is configured.
%
%   preferences = ebrains.setpref(...) also returns an
%   ebrains.util.Preferences object, whose properties are the preferences.
%
%   Example:
%       ebrains.setpref(AutoLogin=true, AutoRenew=false)
%       ebrains.setpref(AutoLogin=true, Scope="temporary")
%
%   See also ebrains.getpref, ebrains.util.Preferences

    arguments
        preferenceValues.?ebrains.util.Preferences
        options.Scope (1,1) string ...
            {mustBeMember(options.Scope, ["personal", "temporary"])} = "personal"
    end

    preferenceObject = ebrains.util.Preferences();

    if options.Scope == "temporary"
        nameValuePairs = namedargs2cell(preferenceValues);
        preferenceObject.setTemporaryValue(nameValuePairs{:})
    else
        preferenceNames = string(fieldnames(preferenceValues));
        for preferenceName = reshape(preferenceNames, 1, [])
            preferenceObject.(preferenceName) = preferenceValues.(preferenceName);
        end
    end

    % Returned only when asked for, so that a call without a semicolon
    % does not display the preferences.
    if nargout > 0
        preferences = preferenceObject;
    end
end
