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
        Client mocks.MockInstancesClient
        TestData
    end
    
    properties (TestParameter)
        Stage = {"RELEASED", "IN_PROGRESS"}
    end
    
    methods (TestClassSetup)
        function setupTestData(testCase)
            testCase.TestData.identifier = "test-uuid-12345";
            testCase.TestData.type = "https://openminds.ebrains.eu/core/Dataset";
            testCase.TestData.instance = struct( ...
                'id', testCase.TestData.identifier, ...
                'name', 'Test Dataset', ...
                'description', 'A test dataset');
        end
    end
    
    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = mocks.MockInstancesClient();
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
            client = mocks.MockInstancesClient();
            testCase.verifyClass(client, 'mocks.MockInstancesClient');
            testCase.verifyInstanceOf(client, 'ebrains.kg.api.InstancesClient');
        end
        
        %% listInstances Tests
        function testListInstancesSuccess(testCase)
            % Arrange
            expectedData = struct('data', testCase.TestData.instance);
            testCase.Client.addResponse('OK', expectedData);
            
            % Act
            result = testCase.Client.listInstances("Dataset");
            
            % Assert
            testCase.verifyEqual(result, testCase.TestData.instance);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/instances');
        end
        
        function testListInstancesWithOptionalParams(testCase)
            % Arrange
            testCase.Client.addResponse('OK', struct('data', []));
            
            % Act
            testCase.Client.listInstances("Dataset", ...
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
                @() testCase.Client.listInstances("Dataset"), ...
                'EBRAINS:KG_API:listInstances:InternalServerError');
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
        
        function testGetInstanceANYStage_FirstSucceeds(testCase)
            % Arrange - RELEASED stage succeeds
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            result = testCase.Client.getInstance(testCase.TestData.identifier, "ANY");
            
            % Assert
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 1);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end
        
        function testGetInstanceANYStage_SecondSucceeds(testCase)
            % Arrange - RELEASED fails, IN_PROGRESS succeeds
            testCase.Client.addResponse('NotFound', struct('error', 'Not found'));
            testCase.Client.addResponse('OK', ...
                struct('data', testCase.TestData.instance));
            
            % Act
            result = testCase.Client.getInstance(testCase.TestData.identifier, "ANY");
            
            % Assert
            testCase.verifyEqual(result.id, testCase.TestData.identifier);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
            testCase.Client.verifyRequestURL(2, 'stage=IN_PROGRESS');
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
        
        function testGetInstancesBulkWithMissingIds_ANY_Stage(testCase)
            % Arrange - First call has missing IDs, second call retrieves them
            bulkResponse1 = struct();
            bulkResponse1.data.id1 = struct('data', struct('id', 'id1'), 'error', []);
            bulkResponse1.data.id2 = struct('data', [], 'error', struct('message', 'id2'));
            testCase.Client.addResponse('OK', bulkResponse1);
            
            bulkResponse2 = struct();
            bulkResponse2.data.id2 = struct('data', struct('id', 'id2'), 'error', []);
            testCase.Client.addResponse('OK', bulkResponse2);
            
            % Act
            result = testCase.Client.getInstancesBulk(["id1", "id2"], "ANY");
            
            % Assert
            testCase.verifyLength(result, 2);
            testCase.verifyEqual(testCase.Client.getRequestCount(), 2);
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
            testCase.Client.verifyRequestURL(2, 'stage=IN_PROGRESS');
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
    end
end
