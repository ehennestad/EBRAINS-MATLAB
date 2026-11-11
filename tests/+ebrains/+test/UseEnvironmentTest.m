classdef UseEnvironmentTest < matlab.unittest.TestCase
    % UseEnvironmentTest - Unit tests for ebrains.useEnvironment
    %
    % The Environment preference belongs to the MATLAB session the tests
    % run in, so each test runs with the default preferences and the values
    % of the user are set again at teardown.

    methods (TestMethodSetup)
        function useDefaultPreferences(testCase)
            testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());
        end
    end

    methods (Test)
        function testSetsTheEnvironmentPreference(testCase)
            ebrains.useEnvironment("int")

            testCase.verifyEqual(ebrains.getpref("Environment"), "int");
        end

        function testLeavesTheSavedValueAsItIs(testCase)
            ebrains.useEnvironment("int")

            environmentSetting = ebrains.util.Preferences.getSetting("Environment");
            testCase.verifyTrue(environmentSetting.hasTemporaryValue());
            testCase.verifyFalse(environmentSetting.hasPersonalValue());
        end

        function testTakesPrecedenceOverTheSavedValue(testCase)
            ebrains.setpref(Environment="int")

            ebrains.useEnvironment("prod")

            testCase.verifyEqual(ebrains.getpref("Environment"), "prod");
        end

        function testRejectsUnknownEnvironment(testCase)
            testCase.verifyError(@() ebrains.useEnvironment("bogus"), ...
                'EBRAINS:Common:UnknownEnvironment');
        end
    end
end
