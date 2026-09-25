function preference = getpref(preferenceName)
%getpref - Get the preferences of the EBRAINS Services Toolbox
%   preferences = ebrains.getpref() returns an ebrains.util.Preferences
%   object, whose properties are the preferences. A value assigned to one
%   of them is saved like one set with ebrains.setpref.
%
%   value = ebrains.getpref(preferenceName) returns the value of one
%   preference, such as "AutoLogin".
%
%   See also ebrains.setpref, ebrains.util.Preferences

    arguments
        preferenceName (1,1) string {mustBePreferenceName} = missing
    end

    preference = ebrains.util.Preferences();

    if ~ismissing(preferenceName)
        preference = preference.(preferenceName);
    end
end

function mustBePreferenceName(preferenceName)
    if ismissing(preferenceName)
        return
    end

    preferenceNames = string(properties("ebrains.util.Preferences"));
    if ~ismember(preferenceName, preferenceNames)
        error("EBRAINS:getpref:UnknownPreference", ...
            "There is no preference named ""%s"". The preferences are: %s.", ...
            preferenceName, strjoin(preferenceNames, ", "))
    end
end
