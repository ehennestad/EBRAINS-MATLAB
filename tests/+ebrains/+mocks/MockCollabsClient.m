classdef MockCollabsClient < ebrains.collab.api.CollabsClient & ebrains.mocks.MockHttpTransport
    % MockCollabsClient - Test double that mocks HTTP responses
    %
    % This mock client subclasses CollabsClient and overrides sendRequest
    % to return canned responses instead of making real HTTP calls.
    %
    % Example:
    %   mockClient = ebrains.mocks.MockCollabsClient();
    %   mockClient.addResponse('OK', struct('name', {'d-abc'}));
    %   collabs = mockClient.searchCollabs();

    methods (Access = protected)
        function headers = getDefaultHeader(obj)
            headers = obj.getMockHeaders();
        end

        function response = sendRequest(obj, requestObj, apiURL, httpOpts)
            arguments
                obj (1,1) ebrains.mocks.MockCollabsClient
                requestObj (1,1) matlab.net.http.RequestMessage
                apiURL (1,1) matlab.net.URI
                httpOpts matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end

            response = obj.recordAndRespond(requestObj, apiURL, httpOpts);
        end
    end
end
