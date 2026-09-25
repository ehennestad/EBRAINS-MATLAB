classdef PreferencesFixture < matlab.unittest.fixtures.Fixture
    % PreferencesFixture - Default preferences for a test, the user's restored after
    %
    % The preferences are settings under settings().ebrains, whose
    % personal values MATLAB saves for later sessions and whose temporary
    % values last until MATLAB closes. Applying this fixture records both,
    % clears them so that a test runs with the factory defaults, and sets
    % the recorded ones again at teardown.
    %
    % Usage:
    %   testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());

    properties (Access = private)
        RecordedValues struct  % Personal and temporary values found at setup
    end

    methods
        function setup(fixture)
            preferences = ebrains.getpref();
            fixture.RecordedValues = captureValues(preferences);
            fixture.addTeardown(@() restoreValues(fixture.RecordedValues));
            preferences.reset();
        end
    end
end

function recordedValues = captureValues(preferences)
% captureValues - The personal and temporary value of each preference, if any
    recordedValues = struct("Personal", struct(), "Temporary", struct());
    for preferenceName = reshape(string(properties(preferences)), 1, [])
        setting = ebrains.util.Preferences.getSetting(preferenceName);
        if setting.hasPersonalValue()
            recordedValues.Personal.(preferenceName) = setting.PersonalValue;
        end
        if setting.hasTemporaryValue()
            recordedValues.Temporary.(preferenceName) = setting.TemporaryValue;
        end
    end
end

function restoreValues(recordedValues)
% restoreValues - Set the recorded values again, and clear the rest
    preferences = ebrains.getpref();
    preferences.reset()

    for preferenceName = reshape(string(fieldnames(recordedValues.Personal)), 1, [])
        preferences.(preferenceName) = recordedValues.Personal.(preferenceName);
    end
    nameValuePairs = namedargs2cell(recordedValues.Temporary);
    preferences.setTemporaryValue(nameValuePairs{:})
end
