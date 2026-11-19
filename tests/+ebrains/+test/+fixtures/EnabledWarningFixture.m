classdef EnabledWarningFixture < matlab.unittest.fixtures.Fixture
    % EnabledWarningFixture - A warning turned on for a test, its state restored after
    %
    % The state of a warning belongs to the MATLAB session the tests run
    % in. A test that checks where a warning is turned off needs it on to
    % begin with, whatever the session has set. Applying this fixture turns
    % the warning on and sets the state found at setup again at teardown.
    %
    % Usage:
    %   testCase.applyFixture(ebrains.test.fixtures.EnabledWarningFixture(warningId));

    properties (SetAccess = immutable)
        WarningId (1,1) string  % Identifier of the warning
    end

    methods
        function fixture = EnabledWarningFixture(warningId)
            arguments
                warningId (1,1) string {mustBeNonzeroLengthText}
            end
            fixture.WarningId = warningId;
        end

        function setup(fixture)
            stateAtSetup = warning('on', fixture.WarningId);
            fixture.addTeardown(@() warning(stateAtSetup));
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fixture, other)
            tf = fixture.WarningId == other.WarningId;
        end
    end
end
