classdef EnvironmentVariableFixtureTest < matlab.unittest.TestCase
    % EnvironmentVariableFixtureTest - Tests that the fixture sets a variable and restores its previous state
    %
    % Each test sets the fixture up by hand and deletes it, which runs its
    % teardown, so the state after teardown can be checked in the test.

    properties (Constant)
        VariableName = "EBRAINS_TEST_ENVIRONMENT_VARIABLE_FIXTURE"
    end

    methods (TestMethodSetup)
        function unsetVariableAfterTest(testCase)
            name = testCase.VariableName;
            testCase.addTeardown(@() unsetenv(name));
        end
    end

    methods (Test)
        function testRestoresThePreviousValue(testCase)
            setenv(testCase.VariableName, "before");

            fixture = ebrains.test.fixtures.EnvironmentVariableFixture(testCase.VariableName, "during");
            fixture.setup();
            testCase.verifyEqual(string(getenv(testCase.VariableName)), "during");
            delete(fixture)

            testCase.verifyEqual(string(getenv(testCase.VariableName)), "before");
        end

        function testUnsetsAVariableThatWasNotSet(testCase)
            unsetenv(testCase.VariableName);

            fixture = ebrains.test.fixtures.EnvironmentVariableFixture(testCase.VariableName, "during");
            fixture.setup();
            testCase.verifyTrue(isenv(testCase.VariableName));
            delete(fixture)

            testCase.verifyFalse(isenv(testCase.VariableName));
        end

        function testRestoresAnEmptyValue(testCase)
            setenv(testCase.VariableName, "");

            fixture = ebrains.test.fixtures.EnvironmentVariableFixture(testCase.VariableName, "during");
            fixture.setup();
            delete(fixture)

            testCase.verifyTrue(isenv(testCase.VariableName), ...
                'A variable set to an empty value is set, not unset, after teardown.');
            testCase.verifyEqual(string(getenv(testCase.VariableName)), "");
        end
    end
end
