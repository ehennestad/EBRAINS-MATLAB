classdef MockHttpTransport < handle
    % MockHttpTransport - Canned responses and request recording for KG client mocks
    %
    % Mix this class into a subclass of a KG API client and forward the
    % client's protected sendRequest to recordAndRespond. The mock then
    % returns queued matlab.net.http.ResponseMessage objects instead of
    % contacting the server, and keeps every request for later assertions.
    %
    % Example:
    %   classdef MockInstancesClient < ebrains.kg.api.InstancesClient & ...
    %           ebrains.mocks.MockHttpTransport

    properties
        CannedResponses = {}
        CurrentResponseIndex = 1
        RequestHistory = {}
        RecordRequests = true
    end

    methods
        function addResponse(obj, statusCode, data)
            % Queue a response to be returned by the next sendRequest call
            %
            % Syntax:
            %   mockClient.addResponse(statusCode, data)
            %
            % Input Arguments:
            %   statusCode - HTTP status code name ('OK', 'NotFound', etc.)
            %   data       - Body data (struct, text) or a ready
            %                matlab.net.http.MessageBody

            if isa(data, 'matlab.net.http.MessageBody')
                body = data;
            else
                body = matlab.net.http.MessageBody(data);
            end
            response = matlab.net.http.ResponseMessage(...
                matlab.net.http.StatusCode(statusCode), [], body);
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
            % Output Arguments:
            %   request - Structure with fields:
            %     RequestMessage - The HTTP request message
            %     URL           - The request URI
            %     Options       - HTTP options used
            %     Timestamp     - When request was made

            if index > numel(obj.RequestHistory)
                error('MockHttpTransport:InvalidIndex', ...
                    'Request index %d out of bounds (only %d requests recorded)', ...
                    index, numel(obj.RequestHistory));
            end
            request = obj.RequestHistory{index};
        end

        function payload = getRequestPayload(obj, index)
            % Return the encoded body of a request as it would go on the wire

            request = obj.getRequest(index);
            completed = request.RequestMessage.complete(request.URL);
            payload = char(reshape(completed.Body.Payload, 1, []));
        end

        function verifyRequestMethod(obj, index, expectedMethod)
            % Verify the HTTP method of a specific request

            request = obj.getRequest(index);
            actualMethod = char(request.RequestMessage.Method);
            assert(strcmp(actualMethod, expectedMethod), ...
                'Expected method %s, got %s', expectedMethod, actualMethod);
        end

        function verifyRequestURL(obj, index, expectedPattern)
            % Verify the URL contains expected pattern

            request = obj.getRequest(index);
            actualURL = char(request.URL.EncodedURI);
            assert(contains(actualURL, expectedPattern), ...
                'Expected URL to contain "%s", got "%s"', expectedPattern, actualURL);
        end
    end

    methods (Access = protected)
        function headers = getMockHeaders(~)
            % Headers without an Authorization field, so no token is needed
            headers = [ ...
                matlab.net.http.HeaderField("Content-Type", "application/json"), ...
                matlab.net.http.HeaderField("Accept", "application/json") ...
                ];
        end

        function response = recordAndRespond(obj, requestObj, apiURL, httpOpts)
            % Record the request and return the next canned response

            if obj.RecordRequests
                requestRecord = struct();
                requestRecord.RequestMessage = requestObj;
                requestRecord.URL = apiURL;
                requestRecord.Options = httpOpts;
                requestRecord.Timestamp = datetime('now');
                obj.RequestHistory{end+1} = requestRecord;
            end

            if obj.CurrentResponseIndex <= numel(obj.CannedResponses)
                response = obj.CannedResponses{obj.CurrentResponseIndex};
                obj.CurrentResponseIndex = obj.CurrentResponseIndex + 1;
            else
                error('MockHttpTransport:NoMoreResponses', ...
                    'No more canned responses available. Added %d, requested %d', ...
                    numel(obj.CannedResponses), obj.CurrentResponseIndex);
            end
        end
    end
end
