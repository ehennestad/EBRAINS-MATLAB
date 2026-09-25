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
%   ebrains.internal.getPreferenceDefinitions and loaded through
%   resources/settingsInfo.json. RESET returns the preferences to those
%   defaults. When the settings are not loaded, the preferences read as
%   their defaults and setting one raises an error.
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

    % Each preference is also an element of
    % ebrains.internal.getPreferenceDefinitions. No preference may be named
    % Scope, which ebrains.setpref takes as its own option.
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

            settingsGroup = obj.getSettingsGroup();
            for preferenceName = reshape(string(fieldnames(preferenceValues)), 1, [])
                settingsGroup.(preferenceName).TemporaryValue = preferenceValues.(preferenceName);
            end
        end

        function reset(obj)
        %RESET - Return every preference to its default value
        %   reset(OBJ) removes the value set for each preference, for this
        %   session and for later ones, so that the factory value of its
        %   setting applies again.

            settingsGroup = obj.getSettingsGroup();
            for preferenceName = obj.getPreferenceNames()
                if settingsGroup.(preferenceName).hasTemporaryValue()
                    settingsGroup.(preferenceName).clearTemporaryValue()
                end
                if settingsGroup.(preferenceName).hasPersonalValue()
                    settingsGroup.(preferenceName).clearPersonalValue()
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
            if obj.areSettingsLoaded()
                value = settings().(obj.GroupName).(preferenceName).ActiveValue;
            else
                % Every API request reads a preference, so a toolbox whose
                % settings were not loaded would otherwise fail every
                % request. The defaults still apply; only setting a value
                % needs the settings, and raises the error that says so.
                definitions = ebrains.internal.getPreferenceDefinitions();
                value = definitions([definitions.Name] == preferenceName).FactoryValue;
            end
        end

        function writeValue(obj, preferenceName, value)
        %writeValue - Set the value of a preference for this user
            settingsGroup = obj.getSettingsGroup();
            settingsGroup.(preferenceName).PersonalValue = value;
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
    end

    methods (Static, Access = private)
        function settingsGroup = getSettingsGroup()
        %getSettingsGroup - The settings group holding the preferences

            % MATLAB reads resources/settingsInfo.json of a toolbox folder
            % on the path, so the settings are missing only when the
            % toolbox is on the path without that file, such as when the
            % folder holding the ebrains namespace was copied on its own.
            if ~ebrains.util.Preferences.areSettingsLoaded()
                error("EBRAINS:Preferences:SettingsGroupNotFound", ...
                    "The settings of the EBRAINS Services Toolbox were not " + ...
                    "found. Add the folder that holds both the ebrains " + ...
                    "namespace and the resources folder of the toolbox to " + ...
                    "the MATLAB path.")
            end

            settingsGroup = settings().(ebrains.util.Preferences.GroupName);
        end

        function tf = areSettingsLoaded()
        %areSettingsLoaded - Whether the settings of every preference exist
        %   The group alone is not enough: MATLAB also creates it from the
        %   file holding the values a user has set, without the settings
        %   that only the factory tree declares.
            settingsRoot = settings;
            groupName = ebrains.util.Preferences.GroupName;

            tf = settingsRoot.hasGroup(groupName);
            if ~tf
                return
            end

            definitions = ebrains.internal.getPreferenceDefinitions();
            for definition = definitions
                tf = tf && settingsRoot.(groupName).hasSetting(definition.Name);
            end
        end
    end
end
