classdef EnvironmentVariableFixture < matlab.unittest.fixtures.Fixture
    % EnvironmentVariableFixture - An environment variable set for a test, the previous state restored after
    %
    % Applying this fixture sets the variable to the value, and teardown
    % sets the value it had before again, or unsets the variable if it was
    % not set. It takes the arguments of
    % matlab.unittest.fixtures.EnvironmentVariableFixture, which is
    % available from R2023a only, while the toolbox supports R2022b.
    %
    % Usage:
    %   testCase.applyFixture(ebrains.test.fixtures.EnvironmentVariableFixture( ...
    %       "EBRAINS_BUCKET_SYNC_CONFIG_DIR", folder));

    properties (SetAccess = immutable)
        Name (1,1) string   % Name of the environment variable
        Value (1,1) string  % Value the variable has while the fixture is applied
    end

    methods
        function fixture = EnvironmentVariableFixture(name, value)
            arguments
                name (1,1) string {mustBeNonzeroLengthText}
                value (1,1) string
            end
            fixture.Name = name;
            fixture.Value = value;
        end

        function setup(fixture)
            if isenv(fixture.Name)
                previousValue = string(getenv(fixture.Name));
                fixture.addTeardown(@() setenv(fixture.Name, previousValue));
            else
                fixture.addTeardown(@() unsetenv(fixture.Name));
            end
            setenv(fixture.Name, fixture.Value);
        end
    end

    methods (Access = protected)
        function tf = isCompatible(fixture, other)
            % The framework shares a fixture only with one that sets the same value
            tf = fixture.Name == other.Name && fixture.Value == other.Value;
        end
    end
end
