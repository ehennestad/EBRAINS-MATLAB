classdef KgLiveTest < matlab.unittest.TestCase
    % KgLiveTest - Live checks of the Knowledge Graph clients
    %
    % Reads exercise ebrains.kg.api.InstancesClient and QueriesClient
    % against the real, production Knowledge Graph, fetching RELEASED
    % metadata that needs no special access.
    %
    % Writes never touch production: they target the "preprod" server and
    % the "myspace" space, which is private to the authenticated account
    % and meant for exactly this kind of throwaway instance.
    %
    % jsondecode turns the JSON-LD key "@id" into "x_id", since "@" is not
    % valid in a MATLAB field name; a real instance is read by that name,
    % unlike the "id" field the mock-based InstancesClientTest fixtures
    % assume.
    %
    % Tagged "LiveIntegration"; see BucketLiveTest.

    properties (Constant)
        PersonType = "https://openminds.om-i.org/types/Person"
        DatasetType = "https://openminds.om-i.org/types/Dataset"
        Space = "dataset"
    end

    methods (Test, TestTags = {'LiveIntegration'})
        function testListInstancesReturnsDatasets(testCase)
            client = ebrains.kg.api.InstancesClient();
            result = client.listInstances(testCase.DatasetType, space=testCase.Space, size=5);
            testCase.verifyNotEmpty(result)
        end

        function testGetInstanceByIdMatchesListing(testCase)
            client = ebrains.kg.api.InstancesClient();
            listResult = client.listInstances(testCase.DatasetType, space=testCase.Space, size=1);
            testCase.assumeNotEmpty(listResult, "No dataset instances available to fetch")

            identifier = listResult(1).x_id;
            instance = client.getInstance(identifier, "RELEASED");

            testCase.verifyEqual(instance.x_id, identifier)
        end

        function testListQueries(testCase)
            client = ebrains.kg.api.QueriesClient();
            result = client.listQueries(size=5);
            testCase.verifyClass(result, 'struct')
        end

        function testCreateAndDeleteInstanceRoundTrip(testCase)
            % Always preprod and myspace: this creates a real instance, and
            % neither the production Knowledge Graph nor a shared space is
            % an acceptable place for a disposable test record.
            client = ebrains.kg.api.InstancesClient();
            payloadJson = sprintf(...
                ['{"@type":["%s"],' ...
                 '"https://openminds.om-i.org/props/givenName":"EBRAINS-MATLAB live test",' ...
                 '"https://openminds.om-i.org/props/familyName":"probe-%s"}'], ...
                testCase.PersonType, string(datetime("now", Format="yyyyMMdd-HHmmssSSS")));

            created = client.createNewInstance(payloadJson, space="myspace", Server="preprod");
            identifier = created.data.x_id;
            % A failed assertion before the explicit delete below must not
            % leave the probe instance behind.
            testCase.addTeardown(@() deleteIfPresent(client, identifier));

            testCase.verifyEqual(created.data.x_type, {char(testCase.PersonType)});

            % A newly created instance is a draft, not yet released, so it
            % has to be read back from the "IN_PROGRESS" stage.
            instance = client.getInstance(identifier, "IN_PROGRESS", Server="preprod");
            testCase.verifyEqual(instance.x_id, identifier)

            client.deleteInstance(identifier, Server="preprod");
            testCase.verifyError(...
                @() client.getInstance(identifier, "IN_PROGRESS", Server="preprod"), ...
                'EBRAINS:KG_API:getInstance:NotFound');
        end
    end
end

function deleteIfPresent(client, identifier)
% deleteIfPresent - Best-effort cleanup of a probe instance
    try
        client.deleteInstance(identifier, Server="preprod");
    catch
        % Already removed by the test itself, or the create never
        % succeeded; either way there is nothing left to clean up.
    end
end
