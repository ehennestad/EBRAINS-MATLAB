classdef NamespacedirTest < matlab.unittest.TestCase
    % NamespacedirTest - Unit tests for ebrains.common.namespacedir

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

        function testMissingNamespaceIsNamedInError(testCase)
            testCase.verifyError(...
                @() ebrains.common.namespacedir("ebrains.nosuchnamespace"), ...
                'EBRAINS:Common:NamespaceNotFound');
        end
    end
end
