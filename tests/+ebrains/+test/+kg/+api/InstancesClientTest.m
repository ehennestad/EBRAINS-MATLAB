classdef InstancesClientTest < matlab.unittest.TestCase
    % InstancesClientTest - Unit tests for ebrains.kg.api.InstancesClient
    %
    % This test suite uses MockInstancesClient to test the InstancesClient
    % without making real HTTP requests to the EBRAINS Knowledge Graph API.
    %
    % Run all tests:
    %   runtests('tests/+ebrains/+kg/+api/InstancesClientTest')
    %
    % Run specific test:
    %   runtests('tests/+ebrains/+kg/+api/InstancesClientTest', 'Name', 'testGetInstanceSuccess')
    %
    % Run with tags:
    %   runtests('tests/+ebrains/+kg/+api/InstancesClientTest', 'Tag', 'HelperFunctions')
    
    properties
        Client ebrains.mocks.MockInstancesClient
        TestData
    end
    
    properties (TestParameter)
        Stage = {"RELEASED", "IN_PROGRESS"}

        % Every write and listing operation reports a failed server
        % response the same way, through throwError; this drives that one
        % path for each of them instead of repeating it per operation.
        ErroringOperation = ebrains.test.kg.api.InstancesClientTest.erroringOperations()
    end
    
    methods (TestClassSetup)
        function setupTestData(testCase)
            testCase.TestData.identifier = "test-uuid-12345";
            testCase.TestData.type = "https://openminds.om-i.org/types/Dataset";
            testCase.TestData.instance = struct( ...
                'id', testCase.TestData.identifier, ...
                'name', 'Test Dataset', ...
                'description', 'A test dataset');
        end
    end
    
    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockInstancesClient();
        end
    end
    
    methods (TestMethodTeardown)
        function cleanup(testCase)
            testCase.Client.reset();
        end
    end
    
    methods (Test)
        %% Constructor Tests
        function testConstructor(testCase)
            client = ebrains.mocks.MockInstancesClient();
            testCase.verifyClass(client, 'ebrains.mocks.MockInstancesClient');
            testCase.verifyInstanceOf(client, 'ebrains.kg.api.InstancesClient');
        end
        
        %% listInstances Tests
        function testListInstancesSuccess(testCase)
            % Arrange
            expectedData = struct('data', testCase.TestData.instance);
            testCase.Client.addResponse('OK', expectedData);
            
            % Act
            result = testCase.Client.listInstances("https://openminds.om-i.org/types/Dataset");
            
            % Assert
            testCase.verifyEqual(result, testCase.TestData.instance);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/instances');
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testListInstancesWithOptionalParams(testCase)
            % Arrange
            testCase.Client.addResponse('OK', struct('data', []));
            
            % Act
            testCase.Client.listInstances("https://openminds.om-i.org/types/Dataset", ...
                space="myspace", ...
                searchByLabel="test", ...
                from=uint64(10), ...
                size=uint64(20));
            
            % Assert
            testCase.Client.verifyRequestURL(1, 'space=myspace');
            testCase.Client.verifyRequestURL(1, 'searchByLabel=test');
            testCase.Client.verifyRequestURL(1, 'from=10');
            testCase.Client.verifyRequestURL(1, 'size=20');
        end
        
        function testListInstancesServerError(testCase)
            % Arrange
            testCase.Client.addResponse('InternalServerError', ...
                struct('error', 'Server error'));
            
            % Act & Assert
            testCase.verifyError(...
                @() testCase.Client.listInstances("https://openminds.om-i.org/types/Dataset"), ...
                'EBRAINS:KG_API:listInstances:InternalServerError');
        end
        
        function testListInstancesRejectsAnyStage(testCase)
            % The KG server only knows RELEASED and IN_PROGRESS; "ANY" is a
            % client-side convenience of getInstance and getInstancesBulk.
            testCase.verifyError(...
                @() testCase.Client.listInstances("https://openminds.om-i.org/types/Dataset", stage="ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end
        
        %% getInstance Tests
        function testGetInstanceSuccess(testCase, Stage)
            % Arrange
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            result = testCase.Client.getInstance(testCase.TestData.identifier, Stage);
            
            % Assert
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
        end
        
        function testGetInstanceDefaultStageIsReleasedOnly(testCase)
            % Consumers get published metadata unless they ask for drafts
            testCase.Client.addResponse('NotFound', "missing");
            
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier), ...
                'EBRAINS:KG_API:getInstance:NotFound');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testGetInstanceBothStages_FirstSucceeds(testCase)
            % Arrange - RELEASED stage succeeds
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            result = testCase.Client.getInstance(testCase.TestData.identifier, ["RELEASED", "IN_PROGRESS"]);
            
            % Assert
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testGetInstanceBothStages_SecondSucceeds(testCase)
            % Arrange - RELEASED fails, IN_PROGRESS succeeds
            testCase.Client.addResponse('NotFound', struct('error', 'Not found'));
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            result = testCase.Client.getInstance(testCase.TestData.identifier, ["RELEASED", "IN_PROGRESS"]);
            
            % Assert
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
            testCase.Client.verifyRequestURL(2, 'stage=IN_PROGRESS');
        end
        
        function testGetInstanceBothStages_MissingInBoth(testCase)
            testCase.Client.addResponse('NotFound', "missing");
            testCase.Client.addResponse('NotFound', "missing");
            
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier, ["RELEASED", "IN_PROGRESS"]), ...
                'EBRAINS:KG_API:getInstance:NotFound');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end
        
        function testGetInstanceBothStages_NoRetryAfterOtherErrors(testCase)
            % A failure that is not a miss applies to both stages, so the
            % second stage must not be tried.
            testCase.Client.addResponse('Forbidden', "no access");
            
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier, ["RELEASED", "IN_PROGRESS"]), ...
                'EBRAINS:KG_API:getInstance:Forbidden');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
        end
        
        function testGetInstanceStageOrderIsRespected(testCase)
            % The caller chooses which version wins when both stages hold it
            testCase.Client.addResponse('OK', struct('data', testCase.TestData.instance));
            
            testCase.Client.getInstance(testCase.TestData.identifier, ["IN_PROGRESS", "RELEASED"]);
            
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestURL(1, 'stage=IN_PROGRESS');
        end
        
        function testGetInstanceAcceptsEnumVector(testCase)
            testCase.Client.addResponse('NotFound', "missing");
            testCase.Client.addResponse('OK', struct('data', testCase.TestData.instance));
            
            stages = [ebrains.kg.enum.KGStage.RELEASED, ebrains.kg.enum.KGStage.IN_PROGRESS];
            result = testCase.Client.getInstance(testCase.TestData.identifier, stages);
            
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end
        
        function testGetInstanceDuplicateStagesAreRequestedOnce(testCase)
            testCase.Client.addResponse('NotFound', "missing");
            
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier, ["RELEASED", "RELEASED"]), ...
                'EBRAINS:KG_API:getInstance:NotFound');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
        end
        
        function testGetInstanceRejectsAnyStage(testCase)
            % "ANY" is not a KG stage; pass a vector of stages instead
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier, "ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end
        
        function testGetInstanceRejectsEmptyStage(testCase)
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier, string.empty), ...
                'MATLAB:validators:mustBeNonempty');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end
        
        function testGetInstanceNormalizesIRI(testCase)
            % Arrange
            iriPrefix = "https://kg.ebrains.eu/api/instances/";
            fullIdentifier = iriPrefix + testCase.TestData.identifier;
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            testCase.Client.getInstance(fullIdentifier, "RELEASED");
            
            % Assert - verify the normalized ID is in the URL
            request = testCase.Client.getRequest(1);
            actualURL = char(request.URL.EncodedURI);
            testCase.verifySubstring(actualURL, testCase.TestData.identifier);
            testCase.verifyTrue(~contains(actualURL, iriPrefix));
        end
        
        function testGetInstanceRawOutput(testCase)
            % Arrange
            rawData = '{"id": "test", "raw": true}';
            testCase.Client.addResponse('OK', rawData);
            
            % Act
            result = testCase.Client.getInstance(...
                testCase.TestData.identifier, "RELEASED", RawOutput=true);
            
            % Assert
            testCase.verifyEqual(result, rawData);
        end
        
        function testGetInstanceNotFound(testCase)
            % Arrange
            testCase.Client.addResponse('NotFound', "Not found");
            
            % Act & Assert
            testCase.verifyError(...
                @() testCase.Client.getInstance(testCase.TestData.identifier, "RELEASED"), ...
                'EBRAINS:KG_API:getInstance:NotFound');
        end
        
        function testErrorMessageIncludesTextResponseBody(testCase)
            % A real ResponseMessage is an object, so the body must be read
            % through properties rather than struct fields.
            testCase.Client.addResponse('NotFound', "Instance abc does not exist");
            
            try
                testCase.Client.getInstance("abc", "RELEASED");
                testCase.verifyFail('Expected getInstance to throw');
            catch ME
                testCase.verifyEqual(ME.identifier, 'EBRAINS:KG_API:getInstance:NotFound');
                testCase.verifySubstring(ME.message, 'Instance abc does not exist');
            end
        end
        
        function testErrorMessageIncludesJsonResponseBody(testCase)
            % A decoded JSON error body is a struct and must still be shown
            testCase.Client.addResponse('BadRequest', struct('error', 'invalid stage'));

            try
                testCase.Client.getInstance("abc", "RELEASED");
                testCase.verifyFail('Expected getInstance to throw');
            catch ME
                testCase.verifyEqual(ME.identifier, 'EBRAINS:KG_API:getInstance:BadRequest');
                testCase.verifySubstring(ME.message, 'invalid stage');
            end
        end
        
        function testInternalServerErrorMentionsServer(testCase)
            testCase.Client.addResponse('InternalServerError', "stack trace");
            
            try
                testCase.Client.getInstance("abc", "RELEASED", Server="preprod");
                testCase.verifyFail('Expected getInstance to throw');
            catch ME
                testCase.verifySubstring(ME.message, 'preprod');
            end
        end
        
        %% createNewInstance Tests
        function testCreateNewInstanceSuccess(testCase)
            % Arrange
            payload = '{"@type": "' + testCase.TestData.type + '", "name": "New Dataset"}';
            expectedResult = struct('id', 'new-uuid-12345', 'created', true);
            responseData = matlab.net.http.MessageBody(jsonencode(expectedResult));
            testCase.Client.addResponse('OK', responseData);
            
            % Act
            result = testCase.Client.createNewInstance(payload, space="dataset");
            
            % Assert
            testCase.verifyEqual(result.id, 'new-uuid-12345');
            testCase.verifyTrue(result.created);
            testCase.Client.verifyRequestMethod(1, 'POST');
            testCase.Client.verifyRequestURL(1, '/instances');
            
            % Verify payload was sent
            request = testCase.Client.getRequest(1);
            testCase.verifyNotEmpty(request.RequestMessage.Body);
        end
        
        function testCreateNewInstanceEmptyPayload(testCase)
            % Act & Assert
            testCase.verifyError(...
                @() testCase.Client.createNewInstance("", space="dataset"), ...
                'MATLAB:validators:mustBeNonzeroLengthText');
        end
        
        %% createNewInstanceWithId Tests
        function testCreateNewInstanceWithIdSuccess(testCase)
            % Arrange
            newId = "custom-uuid-12345";
            payload = '{"@type": "' + testCase.TestData.type + '"}';
            expectedResult = struct('id', newId);
            responseData = matlab.net.http.MessageBody(jsonencode(expectedResult));
            testCase.Client.addResponse('OK', responseData);
            
            % Act
            result = testCase.Client.createNewInstanceWithId(newId, payload, space="dataset");
            
            % Assert
            testCase.verifyEqual(result.id, char(newId));
            testCase.Client.verifyRequestMethod(1, 'POST');
            testCase.Client.verifyRequestURL(1, '/instances/' + newId);
        end
        
        %% updateInstance Tests
        function testUpdateInstanceSuccess(testCase)
            % Arrange
            payload = '{"name": "Updated Name"}';
            expectedResult = struct('updated', true);
            responseData = matlab.net.http.MessageBody(jsonencode(expectedResult));
            testCase.Client.addResponse('OK', responseData);
            
            % Act
            result = testCase.Client.updateInstance(testCase.TestData.identifier, payload);
            
            % Assert
            testCase.verifyTrue(result.updated);
            testCase.Client.verifyRequestMethod(1, 'PATCH');
        end
        
        %% replaceInstance Tests
        function testReplaceInstanceSuccess(testCase)
            % Arrange
            payload = '{"@type": "' + testCase.TestData.type + '", "name": "Replaced"}';
            expectedResult = struct('replaced', true);
            responseData = matlab.net.http.MessageBody(jsonencode(expectedResult));
            testCase.Client.addResponse('OK', responseData);
            
            % Act
            result = testCase.Client.replaceInstance(testCase.TestData.identifier, payload);
            
            % Assert
            testCase.verifyTrue(result.replaced);
            testCase.Client.verifyRequestMethod(1, 'PUT');
        end
        
        %% deleteInstance Tests
        function testDeleteInstanceSuccess(testCase)
            % Arrange
            expectedResult = struct('data', struct('deleted', true));
            testCase.Client.addResponse('OK', expectedResult);
            
            % Act
            result = testCase.Client.deleteInstance(testCase.TestData.identifier);
            
            % Assert
            testCase.verifyTrue(result.deleted);
            testCase.Client.verifyRequestMethod(1, 'DELETE');
        end
        
        %% moveInstance Tests
        function testMoveInstanceSuccess(testCase)
            % Arrange
            newSpace = "newspace";
            expectedResult = struct('data', struct('moved', true));
            testCase.Client.addResponse('OK', expectedResult);
            
            % Act
            result = testCase.Client.moveInstance(testCase.TestData.identifier, newSpace);
            
            % Assert
            testCase.verifyTrue(result.moved);
            testCase.Client.verifyRequestMethod(1, 'PUT');
            testCase.Client.verifyRequestURL(1, '/spaces/' + newSpace);
        end
        
        %% releaseInstance Tests
        function testReleaseInstanceSuccess(testCase)
            % Arrange
            expectedResult = struct('data', struct('released', true));
            testCase.Client.addResponse('OK', expectedResult);
            
            % Act
            result = testCase.Client.releaseInstance(testCase.TestData.identifier);
            
            % Assert
            testCase.verifyTrue(result.released);
            testCase.Client.verifyRequestMethod(1, 'PUT');
            testCase.Client.verifyRequestURL(1, '/release');
        end
        
        %% getReleaseStatus Tests
        function testGetReleaseStatusSuccess(testCase)
            % Arrange
            expectedResult = struct('data', struct('status', 'RELEASED'));
            testCase.Client.addResponse('OK', expectedResult);
            
            % Act
            result = testCase.Client.getReleaseStatus(testCase.TestData.identifier);
            
            % Assert
            testCase.verifyEqual(result.status, 'RELEASED');
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/release/status');
        end
        
        %% getInstancesBulk Tests
        function testGetInstancesBulkSingleRedirectsToGetInstance(testCase)
            % Arrange
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            result = testCase.Client.getInstancesBulk(testCase.TestData.identifier, "RELEASED");
            
            % Assert
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.Client.verifyRequestURL(1, '/instances/' + testCase.TestData.identifier);
        end
        
        function testGetInstancesBulkMultiple(testCase)
            % Arrange
            ids = ["id1", "id2", "id3"];
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            bulkResponse.data.id3 = struct('data', struct('id', 'id3'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse);
            
            % Act
            result = testCase.Client.getInstancesBulk(ids, "RELEASED");
            
            % Assert
            testCase.verifyLength(result, 3);
            testCase.Client.verifyRequestMethod(1, 'POST');
            testCase.Client.verifyRequestURL(1, '/instancesByIds');
        end
        
        function testGetInstancesBulkDefaultStageIsReleasedOnly(testCase)
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse);

            [result, missingIds] = testCase.Client.getInstancesBulk(["id1", "id2"]);

            testCase.verifyLength(result, 1);
            testCase.verifyEqual(missingIds, "id2");
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testGetInstancesBulkWithMissingIds_BothStages(testCase)
            % Arrange - First call has missing IDs, second call retrieves them
            bulkResponse1 = struct();
            bulkResponse1.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse1.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse1);
            
            bulkResponse2 = struct();
            bulkResponse2.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse2);
            
            % Act
            result = testCase.Client.getInstancesBulk(["id1", "id2"], ["RELEASED", "IN_PROGRESS"]);
            
            % Assert
            testCase.verifyLength(result, 2);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
            testCase.Client.verifyRequestURL(2, 'stage=IN_PROGRESS');
        end
        
        function testGetInstancesBulkMissingInBothStagesWarnsOnce(testCase)
            % Arrange - id2 is missing in RELEASED and in IN_PROGRESS
            bulkResponse1 = struct();
            bulkResponse1.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse1.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse1);

            bulkResponse2 = struct();
            bulkResponse2.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse2);

            % Act
            result = testCase.verifyWarning(...
                @() testCase.Client.getInstancesBulk(["id1", "id2"], ["RELEASED", "IN_PROGRESS"]), ...
                'EBRAINS:KG_API:InstancesNotFound');

            % Assert
            testCase.verifyLength(result, 1);
            testCase.verifyEqual(result{1}.id, 'id1');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
        end

        function testGetInstancesBulkReturnsMissingIdsWithoutWarning(testCase)
            % Arrange - id2 is missing in the only stage that is searched
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse);

            % Act
            [result, missingIds] = testCase.verifyWarningFree(...
                @() testCase.Client.getInstancesBulk(["id1", "id2"], "RELEASED"));

            % Assert
            testCase.verifyLength(result, 1);
            testCase.verifyEqual(missingIds, "id2");
        end

        function testGetInstancesBulkSendsIdsAsJsonArray(testCase)
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse);

            testCase.Client.getInstancesBulk(["id1", "id2"], "RELEASED");

            testCase.verifyEqual(testCase.Client.getRequestPayload(1), '["id1","id2"]');
        end

        function testGetInstancesBulkSingleMissingIdIsRetriedAsJsonArray(testCase)
            % One id missing in RELEASED leaves a scalar for the IN_PROGRESS
            % retry, which must still be posted as a JSON array.
            bulkResponse1 = struct();
            bulkResponse1.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse1.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse1);

            bulkResponse2 = struct();
            bulkResponse2.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse2);

            testCase.Client.getInstancesBulk(["id1", "id2"], ["RELEASED", "IN_PROGRESS"]);

            testCase.verifyEqual(testCase.Client.getRequestPayload(2), '["id2"]');
        end

        function testGetInstancesBulkStageOrderIsRespected(testCase)
            % Both ids are answered, so the first stage settles the lookup
            % and the request under test is the only one made.
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse);

            testCase.Client.getInstancesBulk(["id1", "id2"], ["IN_PROGRESS", "RELEASED"]);

            testCase.Client.verifyRequestURL(1, 'stage=IN_PROGRESS');
        end

        function testGetInstancesBulkSingleStageAdvisesOtherStage(testCase)
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse);

            testCase.verifyWarning(...
                @() testCase.Client.getInstancesBulk(["id1", "id2"], "RELEASED"), ...
                'EBRAINS:KG_API:InstancesNotFound');
            [~, warningId] = lastwarn();
            testCase.verifyEqual(warningId, 'EBRAINS:KG_API:InstancesNotFound');
            testCase.verifySubstring(lastwarn(), 'try stage IN_PROGRESS');
        end

        function testGetInstancesBulkReportsRequestedIdOverServerErrorText(testCase)
            % The message of a failed entry names the id when the instance
            % is simply not there, but explains itself for anything else.
            % The caller is told which of its ids is missing either way.
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', [], 'error', struct(...
                'code', 403, 'message', 'You do not have permission to read this instance'));
            testCase.Client.addResponse('OK', bulkResponse);

            [result, missingIds] = testCase.Client.getInstancesBulk(["id1", "id2"], "RELEASED");

            testCase.verifyLength(result, 1);
            testCase.verifyEqual(missingIds, "id2");
        end

        function testGetInstancesBulkReportsIdsTheResponseLeavesOut(testCase)
            % An id the response does not mention at all is missing as far
            % as the caller is concerned.
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse);

            [result, missingIds] = testCase.Client.getInstancesBulk(["id1", "id2"], "RELEASED");

            testCase.verifyLength(result, 1);
            testCase.verifyEqual(missingIds, "id2");
        end

        function testGetInstancesBulkMatchesEntriesKeyedByUuid(testCase)
            % The response is keyed by the requested ids, and jsondecode
            % makes a valid MATLAB field name of every key: a leading digit
            % gets an "x" in front, and a "-" becomes "_". The ids are
            % matched to their entry through the same conversion, so the
            % field names here are spelled out as jsondecode produces them.
            uuids = ["08ab00ea-3e19-4300-9d9f-c0ef0ec8e445", ...
                     "b7c4d1f0-1111-2222-3333-444455556666"];
            instanceIRI = 'https://kg.ebrains.eu/api/instances/08ab00ea-3e19-4300-9d9f-c0ef0ec8e445';

            bulkResponse = struct();
            bulkResponse.data.x08ab00ea_3e19_4300_9d9f_c0ef0ec8e445 = ...
                struct('data', struct('x_id', instanceIRI), 'error', []);
            bulkResponse.data.b7c4d1f0_1111_2222_3333_444455556666 = ...
                struct('data', [], 'error', struct('message', 'Instance not found'));
            testCase.Client.addResponse('OK', bulkResponse);

            [result, missingIds] = testCase.Client.getInstancesBulk(uuids, "RELEASED");

            testCase.verifyLength(result, 1);
            testCase.verifyEqual(result{1}.x_id, instanceIRI);
            testCase.verifyEqual(missingIds, uuids(2));
        end

        function testGetInstancesBulkRejectsAnyStage(testCase)
            testCase.verifyError(...
                @() testCase.Client.getInstancesBulk(["id1", "id2"], "ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        %% listTypes Tests
        function testListTypesSuccess(testCase)
            % Arrange
            expectedTypes = struct('data', {{'Type1', 'Type2'}});
            testCase.Client.addResponse('OK', expectedTypes);
            
            % Act
            result = testCase.Client.listTypes();
            
            % Assert
            testCase.verifyLength(result, 2);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/types');
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testListTypesRejectsAnyStage(testCase)
            testCase.verifyError(...
                @() testCase.Client.listTypes(stage="ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end
        
        %% runDynamicQuery Tests
        function testRunDynamicQuerySuccess(testCase)
            % Arrange
            queryPayload = '{"@context": {...}, "query": {...}}';
            expectedResult = struct('data', {{'result1', 'result2'}});
            testCase.Client.addResponse('OK', expectedResult);
            
            % Act
            result = testCase.Client.runDynamicQuery(queryPayload);
            
            % Assert
            testCase.verifyLength(result, 2);
            testCase.Client.verifyRequestMethod(1, 'POST');
            testCase.Client.verifyRequestURL(1, '/queries');
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testRunDynamicQueryRejectsAnyStage(testCase)
            testCase.verifyError(...
                @() testCase.Client.runDynamicQuery('{"query": {}}', stage="ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        %% Error propagation, once for every operation
        function testOperationPropagatesServerError(testCase, ErroringOperation)
            operationName = ErroringOperation{1};
            callArgs = ErroringOperation{2};
            testCase.Client.addResponse('NotFound', struct('detail', 'not found'));

            testCase.verifyError(...
                @() testCase.Client.(operationName)(callArgs{:}), ...
                "EBRAINS:KG_API:" + operationName + ":NotFound");
        end
    end
    
    methods (Test, TestTags = {'IdentifierNormalization'})
        %% Identifier Normalization Tests
        % Note: normalizeIdentifiers is a local function in InstancesClient.m
        % We test it indirectly through public methods that use it
        
        function testGetInstanceNormalizesArrayOfIRIs(testCase)
            % Test that bulk operations normalize IRI prefixes correctly
            % Arrange
            iriPrefix = "https://kg.ebrains.eu/api/instances/";
            id1 = iriPrefix + "id1";
            id2 = "id2";  % without prefix
            id3 = iriPrefix + "id3";
            
            bulkResponse = struct();
            bulkResponse.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            bulkResponse.data.id3 = struct('data', struct('id', 'id3'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse);
            
            % Act
            result = testCase.Client.getInstancesBulk([id1, id2, id3], "RELEASED");
            
            % Assert - all three should be retrieved successfully
            testCase.verifyLength(result, 3);
            
            % Verify the URL doesn't contain the IRI prefix
            request = testCase.Client.getRequest(1);
            requestData = request.RequestMessage.Body.Data;
            testCase.verifyTrue(~any(contains(requestData, iriPrefix)));
        end
        
        function testCreateNewInstanceWithIdNormalizesIRI(testCase)
            % Test that instance creation normalizes IRI-prefixed identifiers
            % Arrange
            iriPrefix = "https://kg.ebrains.eu/api/instances/";
            rawId = "custom-uuid-12345";
            fullIdentifier = iriPrefix + rawId;
            
            payload = '{"@type": "' + testCase.TestData.type + '"}';
            expectedResult = struct('id', char(rawId));
            responseData = matlab.net.http.MessageBody(jsonencode(expectedResult));
            testCase.Client.addResponse('OK', responseData);
            
            % Act
            result = testCase.Client.createNewInstanceWithId(fullIdentifier, payload, space="dataset");
            
            % Assert - normalized ID should be used in URL
            testCase.verifyEqual(expectedResult, result);

            request = testCase.Client.getRequest(1);
            actualURL = char(request.URL.EncodedURI);
            testCase.verifySubstring(actualURL, '/instances/' + rawId);
            testCase.verifyTrue(~contains(actualURL, iriPrefix));
        end
        
        function testUpdateInstanceNormalizesIRI(testCase)
            testCase.Client.addResponse('OK', matlab.net.http.MessageBody('{"updated": true}'));
            
            testCase.Client.updateInstance(testCase.fullIri("uuid-1"), '{"name": "x"}');
            
            testCase.verifyRequestUsesBareUuid(1, "uuid-1", '/instances/uuid-1');
        end
        
        function testReplaceInstanceNormalizesIRI(testCase)
            testCase.Client.addResponse('OK', matlab.net.http.MessageBody('{"replaced": true}'));
            
            testCase.Client.replaceInstance(testCase.fullIri("uuid-1"), '{"name": "x"}');
            
            testCase.verifyRequestUsesBareUuid(1, "uuid-1", '/instances/uuid-1');
        end
        
        function testMoveInstanceNormalizesIRI(testCase)
            testCase.Client.addResponse('OK', struct('data', struct('moved', true)));
            
            testCase.Client.moveInstance(testCase.fullIri("uuid-1"), "newspace");
            
            testCase.verifyRequestUsesBareUuid(1, "uuid-1", '/instances/uuid-1/spaces/newspace');
        end
        
        function testDeleteInstanceNormalizesIRI(testCase)
            testCase.Client.addResponse('OK', struct('data', struct('deleted', true)));
            
            testCase.Client.deleteInstance(testCase.fullIri("uuid-1"));
            
            testCase.verifyRequestUsesBareUuid(1, "uuid-1", '/instances/uuid-1');
        end
    end
    
    methods (Static)
        function parameters = erroringOperations()
        % erroringOperations - One parameter per operation: {name, callArgs}
        %
        %   callArgs are the arguments that reach the operation's own request,
        %   beyond the mock client itself; each name is written once here and
        %   also becomes the parameter's label.
            operations = { ...
                'createNewInstance',       {'{}'}; ...
                'createNewInstanceWithId', {"id1", '{}'}; ...
                'updateInstance',          {"id1", '{}'}; ...
                'replaceInstance',         {"id1", '{}'}; ...
                'deleteInstance',          {"id1"}; ...
                'moveInstance',            {"id1", "newspace"}; ...
                'releaseInstance',         {"id1"}; ...
                'getReleaseStatus',        {"id1"}; ...
                'listTypes',               {}; ...
                'runDynamicQuery',         {'{}'}; ...
                'getInstancesBulk',        {["id1", "id2"]} ...
                };
            parameters = struct();
            for i = 1:size(operations, 1)
                parameters.(operations{i, 1}) = {operations{i, 1}, operations{i, 2}};
            end
        end
    end

    methods (Access = private)
        function iri = fullIri(~, uuid)
            iri = ebrains.common.constant.KgInstanceIRIPrefix + "/" + uuid;
        end
        
        function verifyRequestUsesBareUuid(testCase, requestIndex, uuid, expectedPath)
            request = testCase.Client.getRequest(requestIndex);
            actualURL = char(request.URL.EncodedURI);
            testCase.verifySubstring(actualURL, expectedPath);
            testCase.verifyFalse(contains(actualURL, testCase.fullIri(uuid)));
        end
    end
end
