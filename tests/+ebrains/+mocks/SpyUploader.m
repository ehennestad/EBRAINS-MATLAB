classdef SpyUploader < handle
    % SpyUploader - Test double for the Uploader option of ebrains.bucket.uploadFile
    %
    % Records every call and answers each one with the next queued
    % response. When the queue is empty, a call is answered as accepted,
    % with the ETag "etag<n>" for the n-th call.
    %
    % Example:
    %   spy = ebrains.mocks.SpyUploader();
    %   spy.Responses = {{false, ebrains.mocks.SpyUploader.refused(503, 'SlowDown')}};
    %   ebrains.bucket.uploadFile(..., Uploader=spy.asFunction());
    %   offsets = cellfun(@(c) c.Options.Offset, spy.Calls);

    properties
        % One struct per call, with the fields SourceFile, Url and Options,
        % the name-value arguments of the call as a struct
        Calls = {}
        % Queue of answers, each a cell {wasSuccess, response}
        Responses = {}
    end

    methods
        function uploader = asFunction(obj)
            % asFunction - Function handle with the signature of the Uploader option
            uploader = @(sourceFile, url, varargin) obj.upload(sourceFile, url, varargin{:});
        end

        function [wasSuccess, response] = upload(obj, sourceFile, url, varargin)
            % upload - Record the call and answer it
            obj.Calls{end+1} = struct( ...
                "SourceFile", sourceFile, "Url", url, "Options", struct(varargin{:}));

            if isempty(obj.Responses)
                wasSuccess = true;
                response = ebrains.mocks.SpyUploader.accepted("etag" + numel(obj.Calls));
            else
                answer = obj.Responses{1};
                obj.Responses(1) = [];
                [wasSuccess, response] = answer{:};
            end
        end
    end

    methods (Static)
        function response = accepted(etag)
            % accepted - Response of a store that accepted a part, with the ETag in quotes as a store sends it
            response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode.OK, ...
                matlab.net.http.HeaderField("ETag", """" + etag + """"));
        end

        function response = refused(statusCode, bodyText)
            % refused - Response of a store that refused a part
            response = matlab.net.http.ResponseMessage(matlab.net.http.StatusCode(statusCode), [], ...
                matlab.net.http.MessageBody(bodyText));
        end
    end
end
