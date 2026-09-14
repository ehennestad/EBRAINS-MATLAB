classdef BucketsClient < ebrains.common.internal.HttpClient
% BucketsClient - Client for the bucket endpoints of the EBRAINS Data Proxy
%
%   Each method mirrors one endpoint under /buckets of the Data Proxy API.
%   An object name is sent as a single path segment, so a name that holds
%   "/" (a folder within the bucket) reaches the server percent-encoded.
%
%   The functions of the ebrains.bucket namespace build on this client and
%   are the intended entry point. Use the client directly when an endpoint
%   is needed on its own.
%
%   Example:
%       client = ebrains.bucket.api.BucketsClient();
%       bucketStat = client.getBucketStat("my-bucket");
%
%   See also ebrains.bucket.listBucketObjects, ebrains.bucket.getBucketObject,
%   ebrains.bucket.renameObject

    properties (Constant, Access = protected)
        ErrorIdPrefix = "EBRAINS:Bucket"
    end

    methods
        function bucketStat = getBucketStat(obj, bucketName)
        % getBucketStat - Get the stat record of a bucket
        %
        %   bucketStat = client.getBucketStat(bucketName) returns a struct
        %   with the fields name, objects_count, bytes and last_modified as
        %   reported by the stat endpoint. The endpoint answers in a single
        %   request, so use it for counts and sizes rather than listing
        %   every object of the bucket.

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
            end

            request = obj.initializeRequestMessage("GET");
            apiUri = obj.buildApiUri(["buckets", bucketName, "stat"]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                bucketStat = response.Body.Data;
            else
                obj.throwError("getBucketStat", response)
            end
        end

        function page = listObjects(obj, bucketName, optionalParams)
        % listObjects - List one page of the objects of a bucket
        %
        %   page = client.listObjects(bucketName) returns the first page of
        %   objects as a struct whose field objects is a struct array with
        %   one element per object.
        %
        %   page = client.listObjects(bucketName, Name=Value) passes the
        %   query parameters of the endpoint:
        %       prefix    - Only objects whose name starts with this text
        %       delimiter - Character that separates folder levels in names
        %       marker    - Name of the object after which the page starts
        %       limit     - Maximum number of objects on the page

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                optionalParams.prefix (1,1) string
                optionalParams.delimiter (1,1) string
                optionalParams.marker (1,1) string
                optionalParams.limit (1,1) int32
            end

            request = obj.initializeRequestMessage("GET");
            apiUri = obj.buildApiUri(["buckets", bucketName], struct.empty, optionalParams);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                page = response.Body.Data;
            else
                obj.throwError("listObjects", response)
            end
        end

        function downloadUrl = getDownloadUrl(obj, bucketName, objectName, optionalParams)
        % getDownloadUrl - Get a temporary URL from which an object can be downloaded
        %
        %   downloadUrl = client.getDownloadUrl(bucketName, objectName)
        %   returns the URL as a string.
        %
        %   downloadUrl = client.getDownloadUrl(..., Name=Value) passes the
        %   query parameters of the endpoint:
        %       inline - Logical, passed through to the endpoint
        %       ttl    - Time to live of the URL, passed through to the endpoint

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
                optionalParams.inline (1,1) logical
                optionalParams.ttl (1,1) int32
            end

            % Without redirect=false the endpoint redirects to the object
            % itself instead of answering with the temporary URL.
            requiredParams = struct('redirect', false);

            request = obj.initializeRequestMessage("GET");
            apiUri = obj.buildApiUri(["buckets", bucketName, objectName], requiredParams, optionalParams);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                downloadUrl = string(response.Body.Data.url);
            else
                obj.throwError("getDownloadUrl", response)
            end
        end

        function renameObject(obj, bucketName, objectName, targetName)
        % renameObject - Rename an object of a bucket
        %
        %   client.renameObject(bucketName, objectName, targetName) gives
        %   the object the name targetName. To rename a folder, end
        %   objectName with "/".

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
                targetName (1,1) string {mustBeNonzeroLengthText}
            end

            payload = struct('rename', struct('target_name', targetName));

            request = obj.initializeRequestMessage("PATCH", JSONPayload=jsonencode(payload));
            apiUri = obj.buildApiUri(["buckets", bucketName, objectName]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode ~= "OK"
                obj.throwError("renameObject", response)
            end
        end
    end

    methods (Static, Access = private)
        function apiUri = buildApiUri(pathSegments, requiredParams, optionalParams)
        % buildApiUri - URI of an endpoint below the Data Proxy base URL
            arguments
                pathSegments (1,:) string
                requiredParams struct = struct.empty
                optionalParams struct = struct.empty
            end

            apiUri = ebrains.common.internal.buildApiUri(...
                ebrains.common.constant.DataProxyApiBaseUrl(), ...
                pathSegments, requiredParams, optionalParams);
        end
    end
end
