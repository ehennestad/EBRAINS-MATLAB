classdef TokenClientTestCaseTest < matlab.unittest.TestCase
    % TokenClientTestCaseTest - Tests of the session isolation in TokenClientTestCase
    %
    % Runs a test that sets EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW
    % and checks that the variable has its earlier value afterwards, both
    % when it was set and when it was not.

    properties (Constant)
        VariableName = "EBRAINS_MATLAB_FORCE_CLIENT_CREDENTIALS_OAUTH_FLOW"
    end

    methods (TestMethodSetup)
        function restoreVariableAfterTest(testCase)
            wasSet = isenv(testCase.VariableName);
            value = getenv(testCase.VariableName);
            testCase.addTeardown(@() restoreVariable(testCase.VariableName, wasSet, value));
        end
    end

    methods (Test)
        function testUnsetVariableIsUnsetAfterTest(testCase)
            unsetenv(testCase.VariableName);

            runTestThatSetsVariable(testCase);

            testCase.verifyFalse(isenv(testCase.VariableName));
        end

        function testSetVariableKeepsItsValueAfterTest(testCase)
            setenv(testCase.VariableName, "value-before-test");

            runTestThatSetsVariable(testCase);

            testCase.verifyEqual(string(getenv(testCase.VariableName)), "value-before-test");
        end
    end
end

function runTestThatSetsVariable(testCase)
% runTestThatSetsVariable - Run a test that sets the forced flow variable to "true"
    suite = matlab.unittest.TestSuite.fromMethod(?ebrains.test.GetTokenManagerTest, ...
        "testErrorsWhenForcedClientCredentialsCannotAuthenticate");
    result = run(suite);
    testCase.assertTrue(result.Passed, "The test that sets the variable did not pass.");
end

function restoreVariable(name, wasSet, value)
    if wasSet
        setenv(name, value);
    else
        unsetenv(name);
    end
end
