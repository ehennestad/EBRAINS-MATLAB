classdef HasObjectTest < matlab.unittest.TestCase
    % HasObjectTest - Unit tests for ebrains.bucket.internal.hasObject
    %
    % Every call receives a MockBucketsClient, so no request reaches the
    % Data Proxy. Page fixtures are column struct arrays, the shape
    % jsondecode gives a JSON array, and [] for an empty one.

    properties
        Client ebrains.mocks.MockBucketsClient
    end

    methods (TestMethodSetup)
        function createMockClient(testCase)
            testCase.Client = ebrains.mocks.MockBucketsClient();
        end
    end

    methods (Test)
        function testEmptyListingMeansAbsent(testCase)
            testCase.Client.addResponse('OK', makePage(string.empty));

            tf = ebrains.bucket.internal.hasObject(testCase.Client, "my-bucket", "a.txt");

            testCase.verifyFalse(tf);
            testCase.Client.verifyRequestURL(1, '/buckets/my-bucket?prefix=a.txt');
        end

        function testLongerNameOnlyMeansAbsent(testCase)
            % The prefix listing also returns longer names, which must not
            % count as the object.
            testCase.Client.addResponse('OK', makePage("a.txt.bak"));

            tf = ebrains.bucket.internal.hasObject(testCase.Client, "my-bucket", "a.txt");

            testCase.verifyFalse(tf);
        end

        function testExactNameAmongLongerOnesMeansPresent(testCase)
            testCase.Client.addResponse('OK', makePage(["a.txt.bak", "a.txt"]));

            tf = ebrains.bucket.internal.hasObject(testCase.Client, "my-bucket", "a.txt");

            testCase.verifyTrue(tf);
        end

        function testFolderIsPresentWhenAnObjectIsBelowIt(testCase)
            % One listed object is enough to tell, so the listing asks for
            % one.
            testCase.Client.addResponse('OK', makePage("d/x.txt"));

            tf = ebrains.bucket.internal.hasObject(testCase.Client, "my-bucket", "d/");

            testCase.verifyTrue(tf);
            testCase.Client.verifyRequestURL(1, 'prefix=d/');
            testCase.Client.verifyRequestURL(1, 'limit=1');
        end

        function testFolderWithNothingBelowIsAbsent(testCase)
            testCase.Client.addResponse('OK', makePage(string.empty));

            tf = ebrains.bucket.internal.hasObject(testCase.Client, "my-bucket", "d/");

            testCase.verifyFalse(tf);
        end

        function testListingErrorPropagates(testCase)
            testCase.Client.addResponse('NotFound', 'Bucket not found');

            testCase.verifyError(...
                @() ebrains.bucket.internal.hasObject(testCase.Client, "my-bucket", "a.txt"), ...
                'EBRAINS:Bucket:listObjects:NotFound');
        end
    end
end

function page = makePage(objectNames)
% makePage - Listing page as jsondecode returns it from the Data Proxy
    if isempty(objectNames)
        page = struct('objects', []);
        return
    end
    names = cellstr(reshape(objectNames, [], 1));
    sizes = num2cell(zeros(numel(names), 1));
    page = struct('objects', struct('name', names, 'bytes', sizes));
end
