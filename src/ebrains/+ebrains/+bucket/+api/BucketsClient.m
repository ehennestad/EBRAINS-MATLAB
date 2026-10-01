classdef BucketsClient < ebrains.common.internal.HttpClient
% BucketsClient - Client for the bucket endpoints of the EBRAINS Data Proxy
%
%   Each method mirrors one endpoint under /buckets of the Data Proxy API:
%   bucket stat, one page of the object listing, temporary download and
%   upload URLs, the three requests of a multipart upload, rename, and
%   delete.
%   An object name that holds "/" (a folder within the bucket) is sent with
%   the "/" as path separators, since the proxy takes the rest of the path
%   as the name. The temporary URLs the proxy returns are made valid URLs
%   before they are handed back; see the local functions in this file.
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
%   ebrains.bucket.renameObject, ebrains.bucket.deleteObject

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
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName)], ...
                requiredParams, optionalParams);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                downloadUrl = encodeRawUrlCharacters(response.Body.Data.url);
            else
                obj.throwError("getDownloadUrl", response)
            end
        end

        function uploadUrl = getUploadUrl(obj, bucketName, objectName)
        % getUploadUrl - Get a temporary URL to which an object can be uploaded
        %
        %   uploadUrl = client.getUploadUrl(bucketName, objectName) returns
        %   the URL as a string. A PUT of the file content to that URL
        %   creates or replaces the object, which
        %   ebrains.external.webprogress.upload does with a progress
        %   display.

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
            end

            % The endpoint is a PUT without a body, which MATLAB warns
            % about on purpose. The warning is off for this request only.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));

            request = obj.initializeRequestMessage("PUT");
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName)]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                uploadUrl = encodeRawUrlCharacters(response.Body.Data.url);
            else
                obj.throwError("getUploadUrl", response)
            end
        end

        function uploadId = initiateMultipartUpload(obj, bucketName, objectName)
        % initiateMultipartUpload - Start a multipart upload of an object
        %
        %   uploadId = client.initiateMultipartUpload(bucketName, objectName)
        %   returns the id of the new multipart upload as a string. The
        %   requests for the part URLs and for the completion carry it;
        %   see getMultipartUploadUrl and completeMultipartUpload. The
        %   object appears in the bucket once the upload is completed.

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
            end

            % The endpoint is a PUT without a body, which MATLAB warns
            % about on purpose. The warning is off for this request only.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));

            request = obj.initializeRequestMessage("PUT");
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName), "multipart"]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                uploadId = string(response.Body.Data.uploadId);
            else
                obj.throwError("initiateMultipartUpload", response)
            end
        end

        function partUrl = getMultipartUploadUrl(obj, bucketName, objectName, uploadId, partNumber)
        % getMultipartUploadUrl - Get a temporary URL to which one part of a multipart upload can be sent
        %
        %   partUrl = client.getMultipartUploadUrl(bucketName, objectName, uploadId, partNumber)
        %   returns the URL as a string. A PUT of the bytes of the part to
        %   that URL stores the part, and the response carries the ETag
        %   that completeMultipartUpload needs. Part numbers start at 1.
        %   ebrains.external.webprogress.upload sends a byte range of a
        %   file this way with its Offset and NumBytes options.

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
                uploadId (1,1) string {mustBeNonzeroLengthText}
                partNumber (1,1) double {mustBeInteger, mustBePositive}
            end

            % The endpoint is a PUT without a body, which MATLAB warns
            % about on purpose. The warning is off for this request only.
            warnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningCleanup = onCleanup(@() warning(warnState));

            request = obj.initializeRequestMessage("PUT");
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName), ...
                "multipart", uploadId, string(partNumber)]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                partUrl = encodeRawUrlCharacters(response.Body.Data.url);
            else
                obj.throwError("getMultipartUploadUrl", response)
            end
        end

        function completeMultipartUpload(obj, bucketName, objectName, uploadId, partETags)
        % completeMultipartUpload - Assemble the parts of a multipart upload into the object
        %
        %   client.completeMultipartUpload(bucketName, objectName, uploadId, partETags)
        %   sends the ETags of the parts in part order, so partETags(n) is
        %   the ETag the store returned for part n. The double quotes the
        %   store puts around an ETag are removed, since the Data Proxy
        %   takes the map without them. The object is in the bucket once
        %   the request has been answered.

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
                uploadId (1,1) string {mustBeNonzeroLengthText}
                partETags (1,:) string {mustBeNonzeroLengthText}
            end

            % The map is a JSON object keyed by part number. A struct cannot
            % have a field named "1", so it is built as a containers.Map.
            partNumbers = cellstr(string(1:numel(partETags)));
            etagMap = containers.Map(partNumbers, cellstr(strip(partETags, '"')));

            request = obj.initializeRequestMessage("PUT", JSONPayload=jsonencode(etagMap));
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName), ...
                "multipart", uploadId]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode ~= "OK"
                obj.throwError("completeMultipartUpload", response)
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
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName)]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode ~= "OK"
                obj.throwError("renameObject", response)
            end
        end
        function deleteObject(obj, bucketName, objectName)
        % deleteObject - Delete an object of a bucket
        %
        %   client.deleteObject(bucketName, objectName) removes the object
        %   from the bucket. To delete a folder with everything in it, end
        %   objectName with "/". The proxy processes a folder deletion
        %   asynchronously: it answers 201 when the request is queued, and
        %   the objects may remain listed until it has completed.

            arguments
                obj (1,1) ebrains.bucket.api.BucketsClient
                bucketName (1,1) string {mustBeNonzeroLengthText}
                objectName (1,1) string {mustBeNonzeroLengthText}
            end

            request = obj.initializeRequestMessage("DELETE");
            apiUri = obj.buildApiUri(["buckets", bucketName, objectPathSegments(objectName)]);
            response = obj.sendRequest(request, apiUri);

            % A single object is deleted at once (200); a folder deletion is
            % queued (201), so any 2xx status is success.
            statusCode = int32(response.StatusCode);
            if statusCode < 200 || statusCode >= 300
                obj.throwError("deleteObject", response)
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

function segments = objectPathSegments(objectName)
% objectPathSegments - Path segments of an object name, one per folder level
%
%   The Data Proxy takes the rest of the request path as the object name, so
%   "/" in a name has to reach it as a path separator. Sent percent-encoded
%   within one segment, the name arrives with a literal "%2F", and the
%   temporary URL the proxy then signs is refused by the object store. A
%   trailing "/" (a folder, for rename) becomes a trailing empty segment,
%   which keeps the trailing "/" in the request path.
    segments = reshape(split(objectName, "/"), 1, []);
end

function url = encodeRawUrlCharacters(url)
% encodeRawUrlCharacters - Percent-encode characters that are not valid in a URL
%
%   The temporary URLs the Data Proxy hands out hold raw spaces, in the
%   object path and in the content-disposition query value, which a URI
%   parser rejects. A raw space or non-ASCII character is never valid in a
%   URL, so encoding it cannot change the meaning, and the object store
%   verifies the signature against the encoded form. Characters a URL may
%   hold, existing percent escapes included, are left as they are.
    url = char(url);
    validCharacters = ['A':'Z', 'a':'z', '0':'9', '-._~:/?#[]@!$&''()*+,;=%'];
    rawCharacters = unique(url(~ismember(url, validCharacters)));
    for rawCharacter = rawCharacters
        escape = sprintf('%%%02X', unicode2native(rawCharacter, 'UTF-8'));
        url = strrep(url, rawCharacter, escape);
    end
    url = string(url);
end
