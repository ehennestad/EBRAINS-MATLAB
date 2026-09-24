classdef QueriesClientTest < matlab.unittest.TestCase
    % QueriesClientTest - Unit tests for ebrains.kg.api.QueriesClient
    %
    % Uses MockQueriesClient so that no request reaches the EBRAINS
    % Knowledge Graph API.

    properties
        Client ebrains.mocks.MockQueriesClient
    end

    properties (TestParameter)
        % Names the query endpoints bind to their own request parameters
        ReservedName = {'stage', 'from', 'size', 'returnTotalResults', ...
            'instanceId', 'restrictToSpaces'}
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

        %% runDynamicQuery Tests
        function testRunDynamicQuerySuccess(testCase)
            testCase.Client.addResponse('OK', struct('data', {{'result1', 'result2'}}));

            result = testCase.Client.runDynamicQuery('{"@context": {}, "query": {}}');

            testCase.verifyLength(result, 2);
            testCase.Client.verifyRequestMethod(1, 'POST');
            testCase.Client.verifyRequestURL(1, '/queries');
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end

        function testRunDynamicQueryRepeatsRestrictToSpaces(testCase)
            % The endpoint expects one restrictToSpaces parameter per space,
            % not a single comma separated value.
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runDynamicQuery('{"query": {}}', ...
                restrictToSpaces=["dataset", "common"]);

            testCase.Client.verifyRequestURL(1, 'restrictToSpaces=dataset&restrictToSpaces=common');
        end

        function testRunDynamicQueryRejectsAnyStage(testCase)
            testCase.verifyError(...
                @() testCase.Client.runDynamicQuery('{"query": {}}', stage="ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        %% runQueryById Tests
        function testRunQueryByIdSuccess(testCase)
            testCase.Client.addResponse('OK', struct('data', {{'result1', 'result2'}}));

            result = testCase.Client.runQueryById("query-uuid-12345");

            testCase.verifyLength(result, 2);
            testCase.Client.verifyRequestMethod(1, 'GET');
            testCase.Client.verifyRequestURL(1, '/queries/query-uuid-12345/instances');
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end

        function testRunQueryByIdPassesOptionalParams(testCase)
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runQueryById("query-uuid-12345", ...
                stage="IN_PROGRESS", from=int64(10), size=int64(5), ...
                returnTotalResults=true, instanceId="instance-uuid-67890");

            testCase.Client.verifyRequestURL(1, 'stage=IN_PROGRESS');
            testCase.Client.verifyRequestURL(1, 'from=10');
            testCase.Client.verifyRequestURL(1, 'size=5');
            testCase.Client.verifyRequestURL(1, 'returnTotalResults=1');
            testCase.Client.verifyRequestURL(1, 'instanceId=instance-uuid-67890');
        end

        function testRunQueryByIdRepeatsRestrictToSpaces(testCase)
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runQueryById("query-uuid-12345", ...
                restrictToSpaces=["dataset", "common"]);

            testCase.Client.verifyRequestURL(1, 'restrictToSpaces=dataset&restrictToSpaces=common');
        end

        function testRunQueryByIdNormalizesIRI(testCase)
            rawId = "query-uuid-12345";
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runQueryById( ...
                ebrains.common.constant.KgInstanceIRIPrefix + "/" + rawId);

            actualURL = char(testCase.Client.getRequest(1).URL.EncodedURI);
            testCase.verifySubstring(actualURL, "/queries/" + rawId + "/instances");
            testCase.verifyFalse(contains(actualURL, ...
                ebrains.common.constant.KgInstanceIRIPrefix));
        end

        function testRunQueryByIdRawOutput(testCase)
            rawData = '{"data": [{"@id": "test"}]}';
            testCase.Client.addResponse('OK', rawData);

            result = testCase.Client.runQueryById("query-uuid-12345", RawOutput=true);

            testCase.verifyEqual(result, rawData);
            request = testCase.Client.getRequest(1);
            testCase.verifyFalse(request.Options.ConvertResponse);
        end

        function testRunQueryByIdNotFound(testCase)
            testCase.Client.addResponse('NotFound', "Query does not exist");

            testCase.verifyError(...
                @() testCase.Client.runQueryById("missing-query"), ...
                'EBRAINS:KG_API:runQueryById:NotFound');
        end

        function testRunQueryByIdRejectsAnyStage(testCase)
            testCase.verifyError(...
                @() testCase.Client.runQueryById("query-uuid-12345", stage="ANY"), ...
                'MATLAB:validation:UnableToConvert');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        %% Query filter parameter Tests
        function testRunQueryByIdSendsFilterParametersUnderTheirOwnNames(testCase)
            % A filter declaring "parameter": "search" reads the request
            % parameter of that name, so each one is sent under its own name.
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runQueryById("query-uuid-12345", ...
                QueryParameters=struct(search="hippocampus", region="CA1"));

            testCase.Client.verifyRequestURL(1, 'search=hippocampus');
            testCase.Client.verifyRequestURL(1, 'region=CA1');
            testCase.Client.verifyRequestURL(1, 'stage=RELEASED');
        end

        function testRunDynamicQuerySendsFilterParametersUnderTheirOwnNames(testCase)
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runDynamicQuery('{"query": {}}', ...
                QueryParameters=struct(search="hippocampus"));

            testCase.Client.verifyRequestURL(1, 'search=hippocampus');
        end

        function testQueryParametersDefaultToNone(testCase)
            testCase.Client.addResponse('OK', struct('data', {{'result1'}}));

            testCase.Client.runQueryById("query-uuid-12345");

            actualURL = char(testCase.Client.getRequest(1).URL.EncodedURI);
            testCase.verifyEqual(count(actualURL, '&'), 0);
        end

        function testQueryParametersRejectReservedNames(testCase, ReservedName)
            % The endpoint binds these names to its own request parameters, so
            % a filter of the same name would silently read the wrong value.
            testCase.verifyError(...
                @() testCase.Client.runQueryById("query-uuid-12345", ...
                    QueryParameters=struct((ReservedName), "value")), ...
                'EBRAINS:KG_API:ReservedQueryParameter');
            testCase.verifyEqual(testCase.Client.getRequestCount(), 0);
        end

        function testReservedNameErrorNamesEveryOffendingParameter(testCase)
            testCase.verifyError(...
                @() testCase.Client.runDynamicQuery('{"query": {}}', ...
                    QueryParameters=struct(stage="X", search="ok", size="10")), ...
                'EBRAINS:KG_API:ReservedQueryParameter');
        end
    end
end
