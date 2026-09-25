classdef PreferencesTest < matlab.unittest.TestCase
    % PreferencesTest - Unit tests for ebrains.util.Preferences, ebrains.getpref and ebrains.setpref
    %
    % The preferences are settings under settings().ebrains, which belong
    % to the MATLAB session the tests run in, so each test runs with the
    % factory defaults and the values of the user are set again at
    % teardown (see ebrains.test.fixtures.PreferencesFixture).

    properties
        SettingsGroup
    end

    methods (TestMethodSetup)
        function useDefaultPreferences(testCase)
            testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());
            testCase.SettingsGroup = settings().ebrains;
        end
    end

    methods (Test)
        %% Factory settings
        function testFactorySettingsAreLoadedFromTheToolbox(testCase)
            % The settings exist because MATLAB read the settingsInfo.json
            % of the toolbox and called ebrains.internal.createFactoryTree.
            testCase.verifyTrue(settings().hasGroup("ebrains"));
            testCase.verifyTrue(testCase.SettingsGroup.hasSetting("AutoLogin"));
            testCase.verifyTrue(testCase.SettingsGroup.hasSetting("AutoRenew"));
        end

        function testEveryPreferenceHasASetting(testCase)
            % A property added to ebrains.util.Preferences without a setting
            % in ebrains.internal.createFactoryTree cannot be read or set.
            for preferenceName = reshape(string(properties("ebrains.util.Preferences")), 1, [])
                testCase.verifyTrue(testCase.SettingsGroup.hasSetting(preferenceName), preferenceName);
            end
        end

        function testMissingSettingErrorSaysHowToLoadIt(testCase)
            testCase.verifyError(@() ebrains.util.Preferences.getSetting("NotLoaded"), ...
                'EBRAINS:Preferences:SettingNotFound');

            try
                ebrains.util.Preferences.getSetting("NotLoaded");
            catch exception
                testCase.verifySubstring(exception.message, 'restart MATLAB');
                testCase.verifySubstring(exception.message, 'resources folder');
            end
        end

        function testDefaultsComeFromTheFactoryValues(testCase)
            testCase.verifyFalse(ebrains.getpref("AutoLogin"));
            testCase.verifyTrue(ebrains.getpref("AutoRenew"));
            testCase.verifyFalse(testCase.SettingsGroup.AutoLogin.hasPersonalValue());
        end

        %% Setting and reading
        function testSetprefValueIsReadByGetpref(testCase)
            ebrains.setpref(AutoLogin=true, AutoRenew=false);

            testCase.verifyTrue(ebrains.getpref("AutoLogin"));
            testCase.verifyFalse(ebrains.getpref("AutoRenew"));
            testCase.verifyTrue(testCase.SettingsGroup.AutoLogin.hasPersonalValue());
        end

        function testAssignedPropertyIsStored(testCase)
            preferences = ebrains.getpref();

            preferences.AutoLogin = true;

            testCase.verifyTrue(ebrains.getpref("AutoLogin"));
        end

        function testSetprefReturnsPreferencesWhenAsked(testCase)
            preferences = ebrains.setpref(AutoLogin=true);

            testCase.verifyClass(preferences, 'ebrains.util.Preferences');
            testCase.verifyTrue(preferences.AutoLogin);
        end

        function testResetReturnsToTheDefaults(testCase)
            ebrains.setpref(AutoLogin=true, AutoRenew=false);

            ebrains.getpref().reset();

            testCase.verifyFalse(ebrains.getpref("AutoLogin"));
            testCase.verifyTrue(ebrains.getpref("AutoRenew"));
            testCase.verifyFalse(testCase.SettingsGroup.AutoLogin.hasPersonalValue());
        end

        %% Temporary scope
        function testTemporaryScopeAppliesWithoutChangingSavedValue(testCase)
            % A temporary value takes precedence over the saved one and is
            % dropped when MATLAB closes.
            ebrains.setpref(AutoLogin=true);

            ebrains.setpref(AutoLogin=false, Scope="temporary");

            testCase.verifyFalse(ebrains.getpref("AutoLogin"));
            testCase.verifyTrue(testCase.SettingsGroup.AutoLogin.PersonalValue);
        end

        function testSetTemporaryValueOnPreferencesObject(testCase)
            preferences = ebrains.getpref();

            preferences.setTemporaryValue(AutoRenew=false);

            testCase.verifyFalse(ebrains.getpref("AutoRenew"));
            testCase.verifyFalse(testCase.SettingsGroup.AutoRenew.hasPersonalValue());
        end

        function testSetTemporaryValueConvertsLikeTheProperty(testCase)
            % Assigning 1 to the logical property sets true, and a
            % temporary value is converted the same way.
            preferences = ebrains.getpref();

            preferences.setTemporaryValue(AutoLogin=1);

            testCase.verifyEqual(ebrains.getpref("AutoLogin"), true);
        end

        function testResetClearsTemporaryValue(testCase)
            ebrains.setpref(AutoRenew=false, Scope="temporary");

            ebrains.getpref().reset();

            testCase.verifyTrue(ebrains.getpref("AutoRenew"));
            testCase.verifyFalse(testCase.SettingsGroup.AutoRenew.hasTemporaryValue());
        end

        function testFixtureRestoresTemporaryValue(testCase)
            % A temporary value set in the session before the tests run is
            % cleared for the test and set again afterwards.
            ebrains.setpref(AutoLogin=true, Scope="temporary");

            fixture = ebrains.test.fixtures.PreferencesFixture();
            fixture.setup();
            testCase.verifyFalse(ebrains.getpref("AutoLogin"));

            fixture.teardown();

            testCase.verifyTrue(ebrains.getpref("AutoLogin"));
            testCase.verifyTrue(testCase.SettingsGroup.AutoLogin.hasTemporaryValue());
        end

        function testNoPreferenceIsNamedScope(testCase)
            % ebrains.setpref takes Scope as its own option next to the
            % preference names, so a preference with that name could not be
            % set through it.
            preferenceNames = string(properties("ebrains.util.Preferences"));

            testCase.verifyFalse(ismember("Scope", preferenceNames), ...
                "Scope is reserved for the option of ebrains.setpref.");
        end

        function testSetprefRejectsUnknownScope(testCase)
            testCase.verifyError(@() ebrains.setpref(AutoLogin=true, Scope="forever"), ...
                'MATLAB:validators:mustBeMember');
        end

        function testSetTemporaryValueRejectsUnknownName(testCase)
            preferences = ebrains.getpref();

            testCase.verifyError(@() preferences.setTemporaryValue(NoSuchPreference=true), ...
                'MATLAB:TooManyInputs');
        end

        %% Validation
        function testSetprefRejectsInvalidValue(testCase)
            testCase.verifyError(@() ebrains.setpref(AutoLogin="yes"), ...
                'MATLAB:validation:UnableToConvert');
        end

        function testGetprefRejectsUnknownName(testCase)
            testCase.verifyError(@() ebrains.getpref("NoSuchPreference"), ...
                'EBRAINS:Preferences:UnknownPreference');
        end

        %% Display
        function testDisplayNamesTheToolbox(testCase)
            preferences = ebrains.getpref(); %#ok<NASGU>

            displayText = evalc("disp(preferences)");

            testCase.verifySubstring(displayText, 'EBRAINS Services Toolbox');
            testCase.verifySubstring(displayText, 'AutoLogin');
        end
    end
end
