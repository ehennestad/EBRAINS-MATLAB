classdef MockInstancesClient < ebrains.kg.api.InstancesClient
    % MockInstancesClient - Test double that mocks HTTP responses
    %
    % This mock client subclasses InstancesClient and overrides sendRequest
    % to return canned responses instead of making real HTTP calls.
    %
    % Example:
    %   mockClient = mocks.MockInstancesClient();
    %   mockClient.addResponse('OK', struct('data', myData));
    %   result = mockClient.getInstance('some-id', 'RELEASED');
    
    properties
        CannedResponses = {}
        CurrentResponseIndex = 1
        RequestHistory = {}
        RecordRequests = true
    end
    
    methods
        function obj = MockInstancesClient()
            % Constructor - calls superclass constructor
            obj = obj@ebrains.kg.api.InstancesClient();
        end
        
        function addResponse(obj, statusCode, data)
            % Queue a response to be returned by next sendRequest call
            %
            % Syntax:
            %   mockClient.addResponse(statusCode, data)
            %
            % Input Arguments:
            %   statusCode - HTTP status code string ('OK', 'NotFound', etc.)
            %   data       - Response data structure or string
            %
            % Example:
            %   mockClient.addResponse('OK', struct('data', myData));
            
            response = struct();
            response.StatusCode = matlab.net.http.StatusCode(statusCode);
            response.Body = struct('Data', data);
            obj.CannedResponses{end+1} = response;
        end
        
        function reset(obj)
            % Clear all canned responses and request history
            obj.CannedResponses = {};
            obj.RequestHistory = {};
            obj.CurrentResponseIndex = 1;
        end
        
        function count = getRequestCount(obj)
            % Return number of requests made
            count = numel(obj.RequestHistory);
        end
        
        function request = getRequest(obj, index)
            % Get details of a specific request
            %
            % Syntax:
            %   request = mockClient.getRequest(index)
            %
            % Input Arguments:
            %   index - Request index (1-based)
            %
            % Output Arguments:
            %   request - Structure with fields:
            %     RequestMessage - The HTTP request message
            %     URL           - The request URI
            %     Options       - HTTP options used
            %     Timestamp     - When request was made
            
            if index > numel(obj.RequestHistory)
                error('MockInstancesClient:InvalidIndex', ...
                    'Request index %d out of bounds (only %d requests recorded)', ...
                    index, numel(obj.RequestHistory));
            end
            request = obj.RequestHistory{index};
        end
        
        function verifyRequestMethod(obj, index, expectedMethod)
            % Verify the HTTP method of a specific request
            %
            % Throws an error if the method doesn't match
            
            request = obj.getRequest(index);
            actualMethod = char(request.RequestMessage.Method);
            assert(strcmp(actualMethod, expectedMethod), ...
                'Expected method %s, got %s', expectedMethod, actualMethod);
        end
        
        function verifyRequestURL(obj, index, expectedPattern)
            % Verify the URL contains expected pattern
            %
            % Throws an error if the pattern is not found
            
            request = obj.getRequest(index);
            actualURL = char(request.URL.EncodedURI);
            assert(contains(actualURL, expectedPattern), ...
                'Expected URL to contain "%s", got "%s"', expectedPattern, actualURL);
        end
    end
    
    methods (Access = protected)
        function response = sendRequest(obj, requestObj, apiURL, httpOpts)
            % Override sendRequest to return canned responses instead of making real HTTP calls
            
            arguments
                obj (1,1) mocks.MockInstancesClient
                requestObj (1,1) matlab.net.http.RequestMessage
                apiURL (1,1) matlab.net.URI
                httpOpts matlab.net.http.HTTPOptions = matlab.net.http.HTTPOptions.empty
            end
            
            % Record the request
            if obj.RecordRequests
                requestRecord = struct();
                requestRecord.RequestMessage = requestObj;
                requestRecord.URL = apiURL;
                requestRecord.Options = httpOpts;
                requestRecord.Timestamp = datetime('now');
                obj.RequestHistory{end+1} = requestRecord;
            end
            
            % Return the next canned response
            if obj.CurrentResponseIndex <= numel(obj.CannedResponses)
                response = obj.CannedResponses{obj.CurrentResponseIndex};
                obj.CurrentResponseIndex = obj.CurrentResponseIndex + 1;
            else
                error('MockInstancesClient:NoMoreResponses', ...
                    'No more canned responses available. Added %d, requested %d', ...
                    numel(obj.CannedResponses), obj.CurrentResponseIndex);
            end
        end
    end

    methods (Static, Access = protected)
        function headers = getDefaultHeader()
            headers = [ ...
                matlab.net.http.HeaderField("Content-Type", "application/json"), ...
                matlab.net.http.HeaderField("Accept", "application/json") ...
                ];
        end
    end
end
