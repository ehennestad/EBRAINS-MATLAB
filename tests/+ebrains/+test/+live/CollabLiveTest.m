classdef CollabLiveTest < matlab.unittest.TestCase
    % CollabLiveTest - Live checks of ebrains.collab.api.CollabsClient
    %
    % Exercises collab search against the real EBRAINS Collaboratory API.
    % Tagged "LiveIntegration"; see BucketLiveTest.

    properties (Constant)
        % Bucket names are the collab id in lowercase; see BucketLiveTest.
        % collabTitle filters on the display title, which can change
        % independently of this id, so search by a substring of it instead.
        CollabName = "eivihe-sandbox"
    end

    methods (Test, TestTags = {'LiveIntegration'})
        function testSearchCollabsReturnsResults(testCase)
            client = ebrains.collab.api.CollabsClient();
            collabs = client.searchCollabs(limit=5);
            testCase.verifyClass(collabs, 'struct')
        end

        function testSearchCollabsFindsKnownCollab(testCase)
            client = ebrains.collab.api.CollabsClient();
            collabs = client.searchCollabs(search=extractBefore(testCase.CollabName, "-"));

            testCase.verifyNotEmpty(collabs)
            testCase.verifyTrue(any(string({collabs.name}) == testCase.CollabName))
        end
    end
end
