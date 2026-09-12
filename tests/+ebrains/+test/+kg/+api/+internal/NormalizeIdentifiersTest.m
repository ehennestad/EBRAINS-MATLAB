classdef NormalizeIdentifiersTest < matlab.unittest.TestCase
    % NormalizeIdentifiersTest - Unit tests for ebrains.kg.api.internal.normalizeIdentifiers

    properties (Constant)
        IriPrefix = ebrains.common.constant.KgInstanceIRIPrefix + "/"
    end

    methods (Test)
        function testStripsPrefixFromFullIri(testCase)
            actual = ebrains.kg.api.internal.normalizeIdentifiers(testCase.IriPrefix + "abc");
            testCase.verifyEqual(actual, "abc");
        end

        function testLeavesBareUuidUnchanged(testCase)
            actual = ebrains.kg.api.internal.normalizeIdentifiers("abc");
            testCase.verifyEqual(actual, "abc");
        end

        function testHandlesMixedArrayAndKeepsShape(testCase)
            input = [testCase.IriPrefix + "id1"; "id2"; testCase.IriPrefix + "id3"];
            actual = ebrains.kg.api.internal.normalizeIdentifiers(input);
            testCase.verifyEqual(actual, ["id1"; "id2"; "id3"]);
        end

        function testEmptyInputReturnsEmpty(testCase)
            actual = ebrains.kg.api.internal.normalizeIdentifiers(string.empty(1, 0));
            testCase.verifyEmpty(actual);
        end

        function testAcceptsCharInput(testCase)
            actual = ebrains.kg.api.internal.normalizeIdentifiers(char(testCase.IriPrefix + "abc"));
            testCase.verifyEqual(actual, "abc");
        end
    end
end
