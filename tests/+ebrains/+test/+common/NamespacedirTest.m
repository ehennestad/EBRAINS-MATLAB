classdef NamespacedirTest < matlab.unittest.TestCase
    % NamespacedirTest - Unit tests for ebrains.common.namespacedir
    %
    % A namespace that is not on the path is not covered here: what()
    % returns an empty struct array for it, and namespacedir then errors
    % with a generic "insufficient outputs" message rather than one that
    % names the missing namespace, which looks like an unhandled edge case
    % rather than an intended restriction.

    methods (Test)
        function testResolvesTopLevelNamespace(testCase)
            folderPath = ebrains.common.namespacedir("ebrains.bucket");

            testCase.verifyTrue(isfolder(folderPath));
            testCase.verifyEqual(char(regexp(folderPath, '\+bucket$', 'match', 'once')), '+bucket');
        end

        function testResolvesNestedNamespace(testCase)
            folderPath = ebrains.common.namespacedir("ebrains.bucket.api");

            testCase.verifyTrue(isfolder(folderPath));
            testCase.verifyTrue(endsWith(folderPath, fullfile("+bucket", "+api")));
        end
    end
end
