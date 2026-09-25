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
%   defaults.
%
%   Example:
%       ebrains.setpref(AutoLogin=true)
%       ebrains.getpref("AutoLogin")
%
%   Preferences methods:
%       setTemporaryValue - Set a preference for this MATLAB session only
%       reset             - Return every preference to its default value
%
%   See also ebrains.getpref, ebrains.setpref,
%   ebrains.internal.createFactoryTree

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

        function setTemporaryValue(obj, preferenceName, value)
        %setTemporaryValue - Set a preference for this MATLAB session only
        %   setTemporaryValue(OBJ,preferenceName,value) gives the
        %   preference a value that applies until MATLAB closes and that
        %   takes precedence over the value the user has set, which is left
        %   as it is. RESET removes it, as does clearTemporaryValue on the
        %   setting itself.
        %
        %   ebrains.setpref(...,Scope="temporary") is the shorter way to
        %   set one.
        %
        %   See also ebrains.setpref, reset

            arguments
                obj (1,1) ebrains.util.Preferences
                preferenceName (1,1) string
                value
            end

            obj.assertIsPreferenceName(preferenceName)

            settingsGroup = obj.getSettingsGroup();
            settingsGroup.(preferenceName).TemporaryValue = value;
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
            value = obj.getSettingsGroup().(preferenceName).ActiveValue;
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

        function assertIsPreferenceName(obj, preferenceName)
        %assertIsPreferenceName - Raise an error for a name that is not a preference
            if ismember(preferenceName, obj.getPreferenceNames())
                return
            end

            error("EBRAINS:Preferences:UnknownPreference", ...
                "There is no preference named ""%s"". The preferences are: %s.", ...
                preferenceName, strjoin(obj.getPreferenceNames(), ", "))
        end
    end

    methods (Static, Access = private)
        function settingsGroup = getSettingsGroup()
        %getSettingsGroup - The settings group holding the preferences
            settingsRoot = settings;

            % MATLAB reads resources/settingsInfo.json of a toolbox folder
            % on the path, so the group is missing only when the toolbox
            % is on the path without that file, such as when the folder
            % holding the ebrains namespace was copied on its own.
            if ~settingsRoot.hasGroup(ebrains.util.Preferences.GroupName)
                error("EBRAINS:Preferences:SettingsGroupNotFound", ...
                    "The settings of the EBRAINS Services Toolbox were not " + ...
                    "found. Add the folder that holds both the ebrains " + ...
                    "namespace and the resources folder of the toolbox to " + ...
                    "the MATLAB path.")
            end

            settingsGroup = settingsRoot.(ebrains.util.Preferences.GroupName);
        end
    end
end
