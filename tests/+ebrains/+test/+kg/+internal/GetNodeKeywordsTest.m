classdef GetNodeKeywordsTest < matlab.unittest.TestCase
    % GetNodeKeywordsTest - Unit tests for ebrains.kg.internal.getNodeKeywords

    methods (Test)
        function testRetrievesValuesInRequestedOrder(testCase)
            node = struct('x_id', 'abc-123', 'x_type', {{'https://openminds.om-i.org/types/Dataset'}});

            [id, type] = ebrains.kg.internal.getNodeKeywords(node, "@id", "@type");

            testCase.verifyEqual(id, 'abc-123');
            testCase.verifyEqual(type, {'https://openminds.om-i.org/types/Dataset'});
        end

        function testMissingKeywordReturnsEmptyChar(testCase)
            node = struct('x_id', 'abc-123');

            missing = ebrains.kg.internal.getNodeKeywords(node, "@notPresent");

            testCase.verifyEqual(missing, '');
        end

        function testSingleKeywordRequest(testCase)
            node = struct('x_id', 'abc-123');

            id = ebrains.kg.internal.getNodeKeywords(node, "@id");

            testCase.verifyEqual(id, 'abc-123');
        end
    end
end
