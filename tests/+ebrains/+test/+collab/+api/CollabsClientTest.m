classdef CollabsClientTest < matlab.unittest.TestCase
    % CollabsClientTest - Unit tests for ebrains.collab.api.CollabsClient
    %
    % Uses MockCollabsClient so that no request reaches the Collaboratory.
    % The Environment preference selects the server of a request, so each
    % test runs with the default preferences.

    properties
        Client ebrains.mocks.MockCollabsClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());
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

        function testSearchCollabsPassesOrderRolesAndVisibility(testCase)
            testCase.Client.addResponse('OK', struct('name', {}));

            testCase.Client.searchCollabs(order="desc", roles="editor", visibility="public");

            testCase.Client.verifyRequestURL(1, 'order=desc');
            testCase.Client.verifyRequestURL(1, 'roles=editor');
            testCase.Client.verifyRequestURL(1, 'visibility=public');
        end

        function testSearchCollabsRejectsUnknownOrder(testCase)
            testCase.verifyError(@() testCase.Client.searchCollabs(order="bogus"), ...
                'MATLAB:validators:mustBeMember');
        end

        function testSearchCollabsRejectsUnknownRole(testCase)
            testCase.verifyError(@() testCase.Client.searchCollabs(roles="bogus"), ...
                'MATLAB:validators:mustBeMember');
        end

        function testSearchCollabsRejectsUnknownVisibility(testCase)
            testCase.verifyError(@() testCase.Client.searchCollabs(visibility="bogus"), ...
                'MATLAB:validators:mustBeMember');
        end

        function testSearchCollabsUnauthorized(testCase)
            testCase.Client.addResponse('Unauthorized', 'Token is not active');
            testCase.verifyError(@() testCase.Client.searchCollabs(), ...
                'EBRAINS:Collab:searchCollabs:Unauthorized');
        end

        function testSearchCollabsInIntEnvironment(testCase)
            ebrains.useEnvironment("int")
            testCase.Client.addResponse('OK', struct('name', {}));

            testCase.Client.searchCollabs(limit=1);

            testCase.Client.verifyRequestURL(1, 'https://wiki-int.ebrains.eu/rest/v1/collabs?limit=1');
        end

        function testCreateCollabSuccess(testCase)
            testCase.Client.addResponse('Created', '');

            testCase.Client.createCollab("my-collab", "My collab");

            testCase.Client.verifyRequestMethod(1, 'POST');
            testCase.Client.verifyRequestURL(1, 'https://wiki.ebrains.eu/rest/v1/collabs');
            payload = jsondecode(testCase.Client.getRequestPayload(1));
            testCase.verifyEqual(payload, struct('name', 'my-collab', 'title', 'My collab'));
        end

        function testCreateCollabSendsGivenOptions(testCase)
            testCase.Client.addResponse('Created', '');

            testCase.Client.createCollab("my-collab", "My collab", ...
                description="A test", drive=true, chat=false, public=false);

            payload = jsondecode(testCase.Client.getRequestPayload(1));
            expectedPayload = struct('name', 'my-collab', 'title', 'My collab', ...
                'description', 'A test', 'drive', true, 'chat', false, 'public', false);
            testCase.verifyEqual(payload, expectedPayload);
        end

        function testCreateCollabInIntEnvironment(testCase)
            ebrains.useEnvironment("int")
            testCase.Client.addResponse('Created', '');

            testCase.Client.createCollab("my-collab", "My collab");

            testCase.Client.verifyRequestURL(1, 'https://wiki-int.ebrains.eu/rest/v1/collabs');
        end

        function testCreateCollabConflict(testCase)
            testCase.Client.addResponse('Conflict', 'A collab with that name already exists.');
            testCase.verifyError(@() testCase.Client.createCollab("my-collab", "My collab"), ...
                'EBRAINS:Collab:createCollab:Conflict');
        end

        function testCreateCollabUnauthorized(testCase)
            testCase.Client.addResponse('Unauthorized', 'Token is not active');
            testCase.verifyError(@() testCase.Client.createCollab("my-collab", "My collab"), ...
                'EBRAINS:Collab:createCollab:Unauthorized');
        end

        function testAddTeamUserSendsPutWithoutBody(testCase)
            testCase.Client.addResponse('NoContent', '');

            testCase.Client.addTeamUser("my-collab", "editor", "jdoe");

            testCase.Client.verifyRequestMethod(1, 'PUT');
            testCase.Client.verifyRequestURL(1, ...
                'https://wiki.ebrains.eu/rest/v1/collabs/my-collab/team/editor/users/jdoe');
            request = testCase.Client.getRequest(1);
            testCase.verifyEmpty(request.RequestMessage.Body);
        end

        function testAddTeamUserRejectsUnknownRole(testCase)
            testCase.verifyError(@() testCase.Client.addTeamUser("my-collab", "owner", "jdoe"), ...
                'MATLAB:validators:mustBeMember');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testAddTeamUserUnknownUser(testCase)
            testCase.Client.addResponse('BadRequest', 'The specified user does not exist.');
            testCase.verifyError(@() testCase.Client.addTeamUser("my-collab", "editor", "nobody"), ...
                'EBRAINS:Collab:addTeamUser:BadRequest');
        end

        function testAddTeamUserForbidden(testCase)
            testCase.Client.addResponse('Forbidden', ...
                'You must be an administrator of this collab to perform this action.');
            testCase.verifyError(@() testCase.Client.addTeamUser("my-collab", "editor", "jdoe"), ...
                'EBRAINS:Collab:addTeamUser:Forbidden');
        end

        function testAddTeamUserCollabNotFound(testCase)
            testCase.Client.addResponse('NotFound', 'Collab not found.');
            testCase.verifyError(@() testCase.Client.addTeamUser("no-such-collab", "editor", "jdoe"), ...
                'EBRAINS:Collab:addTeamUser:NotFound');
        end
    end
end
