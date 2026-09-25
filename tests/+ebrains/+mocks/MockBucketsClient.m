classdef MockBucketsClient < ebrains.bucket.api.BucketsClient & ebrains.mocks.MockHttpTransport
    % MockBucketsClient - Test double that mocks HTTP responses
    %
    % This mock client subclasses BucketsClient and overrides transmitRequest
    % to return canned responses instead of making real HTTP calls.
    %
    % Example:
    %   mockClient = ebrains.mocks.MockBucketsClient();
    %   mockClient.addResponse('OK', struct('objects_count', 3, 'bytes', 1024));
    %   bucketStat = mockClient.getBucketStat('my-bucket');

    methods (Access = protected)
        function headers = getDefaultHeader(obj)
            headers = obj.getMockHeaders();
        end

        function response = transmitRequest(obj, requestObj, apiURL, httpOpts)
            arguments
                obj (1,1) ebrains.mocks.MockBucketsClient
                requestObj (1,1) matlab.net.http.RequestMessage
                apiURL (1,1) matlab.net.URI
                httpOpts matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            response = obj.recordAndRespond(requestObj, apiURL, httpOpts);
        end
    end
end
