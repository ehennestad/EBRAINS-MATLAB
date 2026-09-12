classdef QueriesClientTest < matlab.unittest.TestCase
    % QueriesClientTest - Unit tests for ebrains.kg.api.QueriesClient
    %
    % Uses MockQueriesClient so that no request reaches the EBRAINS
    % Knowledge Graph API.

    properties
        Client ebrains.mocks.MockQueriesClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockQueriesClient();
        end
    end

    methods (Test)
        %% listQueries Tests
        function testListQueriesSuccess(testCase)
            queries = struct('id', {'q1', 'q2'});
            testCase.Client.addResponse('OK', struct('data', queries));

            result = testCase.Client.listQueries();

            testCase.verifyEqual(result, queries);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/queries');
        end

        function testListQueriesWithOptionalParams(testCase)
            testCase.Client.addResponse('OK', struct('data', []));

            testCase.Client.listQueries(type="Dataset", size=uint64(5));

            testCase.Client.verifyRequestURL(1, 'type=Dataset');
            testCase.Client.verifyRequestURL(1, 'size=5');
        end

        function testListQueriesServerError(testCase)
            testCase.Client.addResponse('InternalServerError', []);

            testCase.verifyError(@() testCase.Client.listQueries(), ...
                'EBRAINS:KG_API:listQueries:InternalServerError');
        end

        %% getQuery Tests
        function testGetQuerySuccess(testCase)
            query = struct('id', 'q1', 'name', 'Test Query');
            testCase.Client.addResponse('OK', struct('data', query));

            result = testCase.Client.getQuery("q1");

            testCase.verifyEqual(result, query);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/queries/q1');
        end

        function testGetQueryReturnsBodyWithoutDataEnvelope(testCase)
            query = struct('id', 'q1');
            testCase.Client.addResponse('OK', query);

            result = testCase.Client.getQuery("q1");

            testCase.verifyEqual(result, query);
        end

        function testGetQueryNormalizesIRI(testCase)
            iriPrefix = ebrains.common.constant.KgInstanceIRIPrefix + "/";
            testCase.Client.addResponse('OK', struct('data', struct('id', 'q1')));

            testCase.Client.getQuery(iriPrefix + "q1");

            request = testCase.Client.getRequest(1);
            actualURL = char(request.URL.EncodedURI);
            testCase.verifySubstring(actualURL, '/queries/q1');
            testCase.verifyFalse(contains(actualURL, iriPrefix));
        end

        function testGetQueryRawOutput(testCase)
            rawData = '{"id": "q1"}';
            testCase.Client.addResponse('OK', rawData);

            result = testCase.Client.getQuery("q1", RawOutput=true);

            testCase.verifyEqual(result, rawData);
            request = testCase.Client.getRequest(1);
            testCase.verifyFalse(request.Options.ConvertResponse);
        end

        function testGetQueryNotFound(testCase)
            testCase.Client.addResponse('NotFound', "Query q1 does not exist");

            testCase.verifyError(@() testCase.Client.getQuery("q1"), ...
                'EBRAINS:KG_API:getQuery:NotFound');
        end
    end
end
