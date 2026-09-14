classdef CollabsClientTest < matlab.unittest.TestCase
    % CollabsClientTest - Unit tests for ebrains.collab.api.CollabsClient
    %
    % Uses MockCollabsClient so that no request reaches the Collaboratory.

    properties
        Client ebrains.mocks.MockCollabsClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockCollabsClient();
        end
    end

    methods (Test)
        function testSearchCollabsSuccess(testCase)
            collabs = struct('name', {'d-abc'; 'other'}, 'title', {'Dataset'; 'Other'});
            testCase.Client.addResponse('OK', collabs);

            result = testCase.Client.searchCollabs();

            testCase.verifyEqual(result, collabs);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, 'https://wiki.ebrains.eu/rest/v1/collabs');
        end

        function testSearchCollabsPassesQueryParameters(testCase)
            testCase.Client.addResponse('OK', struct('name', {}));

            testCase.Client.searchCollabs(search="dataset", limit=200, offset=400, ...
                orderField="title", memberOnly=true);

            testCase.Client.verifyRequestURL(1, 'search=dataset');
            testCase.Client.verifyRequestURL(1, 'limit=200');
            testCase.Client.verifyRequestURL(1, 'offset=400');
            testCase.Client.verifyRequestURL(1, 'orderField=title');
            testCase.Client.verifyRequestURL(1, 'memberOnly=1');
        end

        function testSearchCollabsRejectsUnknownOrderField(testCase)
            testCase.verifyError(@() testCase.Client.searchCollabs(orderField="bogus"), ...
                'MATLAB:validators:mustBeMember');
        end

        function testSearchCollabsUnauthorized(testCase)
            testCase.Client.addResponse('Unauthorized', 'Token is not active');
            testCase.verifyError(@() testCase.Client.searchCollabs(), ...
                'EBRAINS:Collab:searchCollabs:Unauthorized');
        end
    end
end
