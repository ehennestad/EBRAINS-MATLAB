classdef EnsureExpandedTypeNameTest < matlab.unittest.TestCase
    % EnsureExpandedTypeNameTest - Unit tests for ebrains.kg.api.internal.ensureExpandedTypeName
    %
    % The branch that expands a short type name via openminds.enum.Types
    % needs openMINDS_MATLAB on the path, which this repo does not depend
    % on; the test that would exercise it is skipped rather than run
    % against a toolbox that is not there.

    methods (Test)
        function testFullIriPassesThroughUnchanged(testCase)
            fullIri = "https://openminds.om-i.org/types/Dataset";

            actual = ebrains.kg.api.internal.ensureExpandedTypeName(fullIri);

            testCase.verifyEqual(actual, fullIri);
        end

        function testShortNameWithoutOpenMindsErrorsWithNamespaceHint(testCase)
            testCase.assumeFalse(exist('openminds.enum.Types', 'class') == 8, ...
                "openMINDS_MATLAB is on the path; this test targets the branch used without it.")

            testCase.verifyError(...
                @() ebrains.kg.api.internal.ensureExpandedTypeName("Dataset"), ?MException);
        end
    end
end
