classdef PreferencesFixture < matlab.unittest.fixtures.Fixture
    % PreferencesFixture - Default preferences for a test, the user's restored after
    %
    % The preferences are personal values of the settings under
    % settings().ebrains, which MATLAB saves for later sessions. Applying
    % this fixture records the values the user has set, clears them so that
    % a test runs with the factory defaults, and sets the recorded ones
    % again at teardown.
    %
    % Usage:
    %   testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());

    methods
        function setup(fixture)
            preferences = ebrains.getpref();
            personalValues = capturePersonalValues(preferences);
            fixture.addTeardown(@() restorePersonalValues(personalValues));
            preferences.reset();
        end
    end
end

function personalValues = capturePersonalValues(preferences)
% capturePersonalValues - The value the user set for each preference, if any
    settingsGroup = settings().(preferences.GroupName);

    personalValues = struct();
    for preferenceName = reshape(string(properties(preferences)), 1, [])
        if settingsGroup.(preferenceName).hasPersonalValue()
            personalValues.(preferenceName) = settingsGroup.(preferenceName).PersonalValue;
        end
    end
end

function restorePersonalValues(personalValues)
% restorePersonalValues - Set the recorded values again, and clear the rest
    preferences = ebrains.getpref();
    preferences.reset()

    for preferenceName = reshape(string(fieldnames(personalValues)), 1, [])
        preferences.(preferenceName) = personalValues.(preferenceName);
    end
end
