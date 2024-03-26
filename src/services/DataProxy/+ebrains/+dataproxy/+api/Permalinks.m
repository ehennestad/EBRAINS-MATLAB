classdef Permalinks < ebrains.dataproxy.BaseClient
    % Permalinks No description provided
    %
    % Permalinks Properties:
    %
    %   serverUri           - Base URI to use when calling the API. Allows using a different server
    %                         than specified in the original API spec.
    %   httpOptions         - HTTPOptions used by all requests.
    %   preferredAuthMethod - If operation supports multiple authentication methods, specified which
    %                         method to prefer.
    %   bearerToken         - If Bearer token authentication is used, the token can be supplied 
    %                         here. Note the token is only used if operations are called for which
    %                         the API explicitly specified that Bearer authentication is supported.
    %                         If this has not been specified in the spec but most operations do 
    %                         require Bearer authentication, consider adding the relevant header to
    %                         all requests in the preSend method.
    %   apiKey              - If API key authentication is used, the key can be supplied here. 
    %                         Note the key is only used if operations are called for which
    %                         the API explicitly specified that API key authentication is supported.
    %                         If this has not been specified in the spec but most operations do 
    %                         require API key authentication, consider adding the API key to all
    %                         requests in the preSend method.
    %   httpCredentials     - If Basic or Digest authentication is supported username/password
    %                         credentials can be supplied here as matlab.net.http.Credentials. Note 
    %                         these are only actively used if operations are called for which the 
    %                         API spec has specified they require Basic authentication. If this has
    %                         not been specified in the spec but most operations do require
    %                         Basic authentication, consider setting the Credentials property in the
    %                         httpOptions rather than through httpCredentials.
    %   cookies             - Cookie jar. The cookie jar is shared across all Api classes in the 
    %                         same package. All responses are automatically parsed for Set-Cookie
    %                         headers and cookies are automatically added to the jar. Similarly
    %                         cookies are added to outgoing requests if there are matching cookies 
    %                         in the jar for the given request. Cookies can also be added manually
    %                         by calling the setCookies method on the cookies property. The cookie
    %                         jar is also saved to disk (cookies.mat in the same directory as 
    %                         BaseClient) and reloaded in new MATLAB sessions.
    %
    % Permalinks Methods:
    %
    %   Permalinks - Constructor
    %   accessPermalinkResource - Access a permalink resource. The user is redirected to the object download link.
    %   createPermalink - Creates a shareable permanent link to a bucket object
    %   deletePermalink - Delete a permalink.
    %   listPermalinks - List permalinks
    %   updatePermalink - Updates a shareable permanent link to a bucket object
    %
    % See Also: matlab.net.http.HTTPOptions, matlab.net.http.Credentials, 
    %   CookieJar.setCookies, ebrains.dataproxy.BaseClient

    % This file is automatically generated using OpenAPI
    % Specification version: 1.0.0
    % MATLAB Generator for OpenAPI version: 1.0.9
    

    % Instruct MATLAB Code Analyzer to ignore unnecessary brackets
    %#ok<*NBRAK2> 

    % Class properties
    properties
    end

    % Class methods
    methods
        function obj = Permalinks(options)
            % Permalinks Constructor, creates a Permalinks instance.
            % When called without inputs, tries to load configuration
            % options from JSON file 'ebrains.dataproxy.Client.Settings.json'.
            % If this file is not present, the instance is initialized with 
            % default configuration option. An alternative configuration 
            % file can be provided through the "configFile" Name-Value pair.
            % All other properties of the instance can also be overridden 
            % using Name-Value pairs where Name equals the property name.
            % 
            % Examples:
            %
            %   % Create a client with default options and serverUri
            %   % as parsed from OpenAPI spec (if available)
            %   client = ebrains.dataproxy.api.Permalinks();
            %
            %   % Create a client for alternative server/base URI
            %   client = ebrains.dataproxy.api.Permalinks("serverUri","https://example.com:1234/api/");
            %
            %   % Create a client loading configuration options from 
            %   % JSON configuration file
            %   client = ebrains.dataproxy.api.Permalinks("configFile","myconfig.json");
            %
            %   % Create a client with alternative HTTPOptions and an API key
            %   client = ebrains.dataproxy.api.Permalinks("httpOptions",...
            %       matlab.net.http.HTTPOptions("ConnectTimeout",42),...
            %       "apiKey", "ABC123");

            arguments
                options.configFile string
                options.?ebrains.dataproxy.BaseClient
            end
            % Call base constructor to override any configured settings
            args = namedargs2cell(options);
            obj@ebrains.dataproxy.BaseClient(args{:})
        end

        function [code, result, response] = accessPermalinkResource(obj, permalink_id, optionals)
            % accessPermalinkResource Access a permalink resource. The user is redirected to the object download link.
            % No description provided
            %
            % Required parameters:
            %   permalink_id - id of the permalink, Type: string, Format: uuid
            %
            % Optional name-value parameters:
            %   inline - No description provided, Type: logical
            %
            % Responses:
            %   307: Successful Response
            %   422: Validation Error
            %
            % Returns: 
            %
            % See Also: ebrains.dataproxy.models.

            arguments
              obj ebrains.dataproxy.api.Permalinks
              permalink_id string
              optionals.inline logical
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % Verify that operation supports returning JSON
            specAcceptHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specAcceptHeaders)
                request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            else
                error("ebrains:dataproxy:api:accessPermalinkResource:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","accessPermalinkResource")
            end
            
            % No body input, so no need to check its content type
            
            % No header parameters

            % Configure default httpOptions
            httpOptions = obj.httpOptions;
            % Never convert API response
            httpOptions.ConvertResponse = false;

            % Configure request verb/method
            request.Method = matlab.net.http.RequestMethod('GET');

            % Build the request URI
            if ~isempty(obj.serverUri)
                % If URI specified in object, use that
                uri = obj.serverUri;
            else
                % If no server specified use base path from OpenAPI spec
                uri = matlab.net.URI("https://data-proxy.ebrains.eu//api");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/permalinks/{permalink_id}";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "permalink_id" +"}") = permalink_id;

            % Set query parameters
            if isfield(optionals, "inline"), uri.Query(end+1) = matlab.net.QueryParameter("inline", optionals.inline); end
            
            % No JSON body parameters

            % No form body parameters

            % Operation does not require authorization

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("accessPermalinkResource", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("accessPermalinkResource", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 307
                    result = response.Body.Data;
                case 422
                    result = ebrains.dataproxy.models.HTTPValidationError(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:dataproxy:api:accessPermalinkResource:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","accessPermalinkResource",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % accessPermalinkResource method

        function [code, result, response] = createPermalink(obj, PermalinkCreate)
            % createPermalink Creates a shareable permanent link to a bucket object
            % No description provided
            %
            % Required parameters:
            %   PermalinkCreate - No description provided, Type: PermalinkCreate
            %       Required properties in the model for this call:
            %           object_name
            %           bucket_name
            %       Optional properties in the model for this call:
            %           description
            %
            % No optional parameters
            %
            % Responses:
            %   200: Successful Response
            %   422: Validation Error
            %
            % Returns: PermalinkModel
            %
            % See Also: ebrains.dataproxy.models.PermalinkModel

            arguments
              obj ebrains.dataproxy.api.Permalinks
              PermalinkCreate ebrains.dataproxy.models.PermalinkCreate
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % Verify that operation supports returning JSON
            specAcceptHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specAcceptHeaders)
                request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            else
                error("ebrains:dataproxy:api:createPermalink:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","createPermalink")
            end
            
            % Verify that operation supports JSON or FORM as input
            specContentTypeHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specContentTypeHeaders)
                request.Header(end+1) = matlab.net.http.field.ContentTypeField('application/json');
            elseif ismember("application/x-www-form-urlencoded",specContentTypeHeaders)
                request.Header(end+1) = matlab.net.http.field.ContentTypeField('application/x-www-form-urlencoded');
            else
                error("ebrains:dataproxy:api:createPermalink:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","createPermalink")
            end
            
            % No header parameters

            % Configure default httpOptions
            httpOptions = obj.httpOptions;
            % Never convert API response
            httpOptions.ConvertResponse = false;

            % Configure request verb/method
            request.Method = matlab.net.http.RequestMethod('POST');

            % Build the request URI
            if ~isempty(obj.serverUri)
                % If URI specified in object, use that
                uri = obj.serverUri;
            else
                % If no server specified use base path from OpenAPI spec
                uri = matlab.net.URI("https://data-proxy.ebrains.eu//api");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/permalinks";

            % No path parameters

            % No query parameters
            
            % Set JSON Body
            requiredProperties = [...
                "object_name",...
                "bucket_name",...
            ];
            optionalProperties = [...
                "description",...
            ];
            request.Body(1).Payload = PermalinkCreate.getPayload(requiredProperties,optionalProperties);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "HTTPBearer", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("createPermalink", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("createPermalink", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.dataproxy.models.PermalinkModel(response.Body.Data);
                case 422
                    result = ebrains.dataproxy.models.HTTPValidationError(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:dataproxy:api:createPermalink:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","createPermalink",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % createPermalink method

        function [code, result, response] = deletePermalink(obj, permalink_id)
            % deletePermalink Delete a permalink.
            % No description provided
            %
            % Required parameters:
            %   permalink_id - id of the permalink, Type: string, Format: uuid
            %
            % No optional parameters
            %
            % Responses:
            %   200: Successful Response
            %   422: Validation Error
            %
            % Returns: 
            %
            % See Also: ebrains.dataproxy.models.

            arguments
              obj ebrains.dataproxy.api.Permalinks
              permalink_id string
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % Verify that operation supports returning JSON
            specAcceptHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specAcceptHeaders)
                request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            else
                error("ebrains:dataproxy:api:deletePermalink:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","deletePermalink")
            end
            
            % No body input, so no need to check its content type
            
            % No header parameters

            % Configure default httpOptions
            httpOptions = obj.httpOptions;
            % Never convert API response
            httpOptions.ConvertResponse = false;

            % Configure request verb/method
            request.Method = matlab.net.http.RequestMethod('DELETE');

            % Build the request URI
            if ~isempty(obj.serverUri)
                % If URI specified in object, use that
                uri = obj.serverUri;
            else
                % If no server specified use base path from OpenAPI spec
                uri = matlab.net.URI("https://data-proxy.ebrains.eu//api");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/permalinks/{permalink_id}";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "permalink_id" +"}") = permalink_id;

            % No query parameters
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "HTTPBearer", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("deletePermalink", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("deletePermalink", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = response.Body.Data;
                case 422
                    result = ebrains.dataproxy.models.HTTPValidationError(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:dataproxy:api:deletePermalink:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","deletePermalink",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % deletePermalink method

        function [code, result, response] = listPermalinks(obj, bucket_name, optionals)
            % listPermalinks List permalinks
            % No description provided
            %
            % Required parameters:
            %   bucket_name - name of the bucket, Type: string
            %
            % Optional name-value parameters:
            %   object_name - name of the object. If none, will return all permalinks associated with the bucket, Type: string
            %   offset - offset of the search, Type: int32
            %   limit - number of results, Type: int32
            %   revoked - returns deleted or active permalinks. If none, returns both., Type: logical
            %
            % Responses:
            %   200: Successful Response
            %   422: Validation Error
            %
            % Returns: Array of PermalinkModel
            %
            % See Also: ebrains.dataproxy.models.PermalinkModel

            arguments
              obj ebrains.dataproxy.api.Permalinks
              bucket_name string
              optionals.object_name string
              optionals.offset int32
              optionals.limit int32
              optionals.revoked logical
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % Verify that operation supports returning JSON
            specAcceptHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specAcceptHeaders)
                request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            else
                error("ebrains:dataproxy:api:listPermalinks:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","listPermalinks")
            end
            
            % No body input, so no need to check its content type
            
            % No header parameters

            % Configure default httpOptions
            httpOptions = obj.httpOptions;
            % Never convert API response
            httpOptions.ConvertResponse = false;

            % Configure request verb/method
            request.Method = matlab.net.http.RequestMethod('GET');

            % Build the request URI
            if ~isempty(obj.serverUri)
                % If URI specified in object, use that
                uri = obj.serverUri;
            else
                % If no server specified use base path from OpenAPI spec
                uri = matlab.net.URI("https://data-proxy.ebrains.eu//api");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/permalinks";

            % No path parameters

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("bucket_name", bucket_name);
            if isfield(optionals, "object_name"), uri.Query(end+1) = matlab.net.QueryParameter("object_name", optionals.object_name); end
            if isfield(optionals, "offset"), uri.Query(end+1) = matlab.net.QueryParameter("offset", optionals.offset); end
            if isfield(optionals, "limit"), uri.Query(end+1) = matlab.net.QueryParameter("limit", optionals.limit); end
            if isfield(optionals, "revoked"), uri.Query(end+1) = matlab.net.QueryParameter("revoked", optionals.revoked); end
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "HTTPBearer", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("listPermalinks", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("listPermalinks", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.dataproxy.models.PermalinkModel(response.Body.Data);
                case 422
                    result = ebrains.dataproxy.models.HTTPValidationError(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:dataproxy:api:listPermalinks:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","listPermalinks",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % listPermalinks method

        function [code, result, response] = updatePermalink(obj, permalink_id, PermalinkUpdateForm)
            % updatePermalink Updates a shareable permanent link to a bucket object
            % No description provided
            %
            % Required parameters:
            %   permalink_id - No description provided, Type: string, Format: uuid
            %   PermalinkUpdateForm - No description provided, Type: PermalinkUpdateForm
            %       Required properties in the model for this call:
            %           object_name
            %       Optional properties in the model for this call:
            %
            % No optional parameters
            %
            % Responses:
            %   200: Successful Response
            %   422: Validation Error
            %
            % Returns: PermalinkModel
            %
            % See Also: ebrains.dataproxy.models.PermalinkModel

            arguments
              obj ebrains.dataproxy.api.Permalinks
              permalink_id string
              PermalinkUpdateForm ebrains.dataproxy.models.PermalinkUpdateForm
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % Verify that operation supports returning JSON
            specAcceptHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specAcceptHeaders)
                request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            else
                error("ebrains:dataproxy:api:updatePermalink:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","updatePermalink")
            end
            
            % Verify that operation supports JSON or FORM as input
            specContentTypeHeaders = [...
                "application/json", ...
            ];
            if ismember("application/json",specContentTypeHeaders)
                request.Header(end+1) = matlab.net.http.field.ContentTypeField('application/json');
            elseif ismember("application/x-www-form-urlencoded",specContentTypeHeaders)
                request.Header(end+1) = matlab.net.http.field.ContentTypeField('application/x-www-form-urlencoded');
            else
                error("ebrains:dataproxy:api:updatePermalink:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","updatePermalink")
            end
            
            % No header parameters

            % Configure default httpOptions
            httpOptions = obj.httpOptions;
            % Never convert API response
            httpOptions.ConvertResponse = false;

            % Configure request verb/method
            request.Method = matlab.net.http.RequestMethod('PUT');

            % Build the request URI
            if ~isempty(obj.serverUri)
                % If URI specified in object, use that
                uri = obj.serverUri;
            else
                % If no server specified use base path from OpenAPI spec
                uri = matlab.net.URI("https://data-proxy.ebrains.eu//api");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/permalinks/{permalink_id}";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "permalink_id" +"}") = permalink_id;

            % No query parameters
            
            % Set JSON Body
            requiredProperties = [...
                "object_name",...
            ];
            optionalProperties = [...
            ];
            request.Body(1).Payload = PermalinkUpdateForm.getPayload(requiredProperties,optionalProperties);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "HTTPBearer", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("updatePermalink", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("updatePermalink", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.dataproxy.models.PermalinkModel(response.Body.Data);
                case 422
                    result = ebrains.dataproxy.models.HTTPValidationError(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:dataproxy:api:updatePermalink:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","updatePermalink",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % updatePermalink method

    end %methods
end %class

