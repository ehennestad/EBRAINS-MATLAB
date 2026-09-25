classdef MockQueriesClient < ebrains.kg.api.QueriesClient & ebrains.mocks.MockHttpTransport
    % MockQueriesClient - Test double that mocks HTTP responses
    %
    % This mock client subclasses QueriesClient and overrides transmitRequest
    % to return canned responses instead of making real HTTP calls.
    %
    % Example:
    %   mockClient = ebrains.mocks.MockQueriesClient();
    %   mockClient.addResponse('OK', struct('data', myQuery));
    %   query = mockClient.getQuery('some-id');

    methods (Access = protected)
        function headers = getDefaultHeader(obj)
            headers = obj.getMockHeaders();
        end

        function response = transmitRequest(obj, requestObj, apiURL, httpOpts)
            arguments
                obj (1,1) ebrains.mocks.MockQueriesClient
                requestObj (1,1) matlab.net.http.RequestMessage
                apiURL (1,1) matlab.net.URI
                httpOpts matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            response = obj.recordAndRespond(requestObj, apiURL, httpOpts);
        end
    end
end
