classdef SimpleTest < matlab.unittest.TestCase
    methods(Test)
        function testAddition(testCase)
            actual = 2 + 2;
            expected = 4;
            testCase.verifyEqual(actual, expected);
        end
    end
end
