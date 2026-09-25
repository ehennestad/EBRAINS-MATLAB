classdef Preferences < matlab.mixin.CustomDisplay
%Preferences - Preferences of the EBRAINS Services Toolbox
%   The preferences are the properties of this class. ebrains.getpref
%   reads them and ebrains.setpref sets them.
%
%       Preference name     Description
%       ------------------  -----------------------------------------------
%       AutoLogin (logical) : Whether an API request opens the EBRAINS
%                             login in the browser when no access token
%                             is available. false (default): the request
%                             is sent without a token, which returns
%                             public data, and a request that needs a
%                             token raises an error that asks for
%                             ebrains.authenticate.
%       AutoRenew (logical) : Whether an expired device flow token is
%                             renewed with its refresh token before a
%                             request, which needs no user interaction.
%                             true (default). The client credentials flow
%                             renews its token with the client id and
%                             secret whatever this preference is.
%
%   A value set here is the personal value of a MATLAB setting under
%   settings().ebrains, which MATLAB saves for later sessions. The default
%   of each preference is its factory value, declared in
%   ebrains.internal.createFactoryTree and loaded through
%   resources/settingsInfo.json. RESET returns the preferences to those
%   defaults. Reading or setting a preference whose setting is not loaded
%   raises an error that says how to load it.
%
%   Example:
%       ebrains.setpref(AutoLogin=true)
%       ebrains.getpref("AutoLogin")
%
%   Preferences methods:
%       setTemporaryValue - Set preferences for this MATLAB session only
%       reset             - Return every preference to its default value
%
%   See also ebrains.getpref, ebrains.setpref,
%   ebrains.internal.createFactoryTree

    % Each preference is also a setting declared in
    % ebrains.internal.createFactoryTree. No preference may be named Scope,
    % which ebrains.setpref takes as its own option.
    properties (Dependent)
        AutoLogin (1,1) logical
        AutoRenew (1,1) logical
    end

    properties (Constant, Hidden)
        GroupName = "ebrains"  % Settings group the values are stored in
    end

    methods
        function value = get.AutoLogin(obj)
            value = obj.readValue("AutoLogin");
        end

        function obj = set.AutoLogin(obj, value)
            obj.writeValue("AutoLogin", value)
        end

        function value = get.AutoRenew(obj)
            value = obj.readValue("AutoRenew");
        end

        function obj = set.AutoRenew(obj, value)
            obj.writeValue("AutoRenew", value)
        end

        function setTemporaryValue(obj, preferenceValues)
        %setTemporaryValue - Set preferences for this MATLAB session only
        %   setTemporaryValue(OBJ,Name=Value) gives one or more preferences
        %   a value that applies until MATLAB closes and that takes
        %   precedence over the value the user has set, which is left as it
        %   is. A value is validated and converted as when it is assigned
        %   to the property, so AutoLogin=1 sets true. RESET removes the
        %   values, as does clearTemporaryValue on a setting itself.
        %
        %   ebrains.setpref(...,Scope="temporary") does the same.
        %
        %   See also ebrains.setpref, reset

            arguments
                obj (1,1) ebrains.util.Preferences
                preferenceValues.?ebrains.util.Preferences
            end

            for preferenceName = reshape(string(fieldnames(preferenceValues)), 1, [])
                setting = obj.getSetting(preferenceName);
                setting.TemporaryValue = preferenceValues.(preferenceName);
            end
        end

        function reset(obj)
        %RESET - Return every preference to its default value
        %   reset(OBJ) removes the value set for each preference, for this
        %   session and for later ones, so that the factory value of its
        %   setting applies again.

            for preferenceName = obj.getPreferenceNames()
                setting = obj.getSetting(preferenceName);
                if setting.hasTemporaryValue()
                    setting.clearTemporaryValue()
                end
                if setting.hasPersonalValue()
                    setting.clearPersonalValue()
                end
            end
        end
    end

    methods (Access = protected) % CustomDisplay override
        function header = getHeader(obj)
            header = sprintf('  %s for the EBRAINS Services Toolbox:\n', ...
                matlab.mixin.CustomDisplay.getClassNameForHeader(obj));
        end
    end

    methods (Access = private)
        function value = readValue(obj, preferenceName)
        %readValue - The value that applies for a preference
            value = obj.getSetting(preferenceName).ActiveValue;
        end

        function writeValue(obj, preferenceName, value)
        %writeValue - Set the value of a preference for this user
            setting = obj.getSetting(preferenceName);
            setting.PersonalValue = value;
        end

        function preferenceNames = getPreferenceNames(obj)
        %getPreferenceNames - Names of the preferences, as a string row
            preferenceNames = reshape(string(properties(obj)), 1, []);
        end
    end

    methods (Static, Hidden)
        function assertIsPreferenceName(preferenceName)
        %assertIsPreferenceName - Raise an error for a name that is not a preference
        %   ebrains.util.Preferences.assertIsPreferenceName(preferenceName)
        %   raises EBRAINS:Preferences:UnknownPreference, listing the
        %   preferences, when preferenceName is not one of them.
        %   ebrains.getpref uses it to check the name it is given; the
        %   functions that take Name=Value pairs have MATLAB check them.

            arguments
                preferenceName (1,1) string
            end

            preferenceNames = reshape(string(properties("ebrains.util.Preferences")), 1, []);
            if ismember(preferenceName, preferenceNames)
                return
            end

            error("EBRAINS:Preferences:UnknownPreference", ...
                "There is no preference named ""%s"". The preferences are: %s.", ...
                preferenceName, strjoin(preferenceNames, ", "))
        end

        function setting = getSetting(preferenceName)
        %getSetting - The matlab.settings.Setting that holds a preference
        %   setting = ebrains.util.Preferences.getSetting(preferenceName)
        %   returns the setting under settings().ebrains, or raises
        %   EBRAINS:Preferences:SettingNotFound when it is not loaded.

            arguments
                preferenceName (1,1) string
            end

            settingsRoot = settings;
            groupName = ebrains.util.Preferences.GroupName;

            % MATLAB loads the settings from resources/settingsInfo.json
            % when the toolbox folder is added to the path, and keeps them
            % until the folder is added again. A setting is therefore
            % missing when the folder is on the path without that file, or
            % when the toolbox was updated in place during the session. The
            % group existing is no evidence, since MATLAB also creates it
            % from the file of values the user has set, without settings.
            isLoaded = settingsRoot.hasGroup(groupName) ...
                && settingsRoot.(groupName).hasSetting(preferenceName);
            if ~isLoaded
                error("EBRAINS:Preferences:SettingNotFound", ...
                    "The setting ""%s"" of the EBRAINS Services Toolbox was not " + ...
                    "found. If the toolbox was updated in this MATLAB session, " + ...
                    "restart MATLAB, or remove the toolbox folder from the path " + ...
                    "and add it again. Otherwise add the folder that holds both " + ...
                    "the ebrains namespace and the resources folder of the " + ...
                    "toolbox to the MATLAB path.", preferenceName)
            end

            setting = settingsRoot.(groupName).(preferenceName);
        end
    end
end
