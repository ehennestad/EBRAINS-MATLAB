classdef Admin < ebrains.dataproxy.BaseClient
    % Admin No description provided
    %
    % Admin Properties:
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
    % Admin Methods:
    %
    %   Admin - Constructor
    %   getBucketAcl - Get Bucket Acl
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
        function obj = Admin(options)
            % Admin Constructor, creates a Admin instance.
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
            %   client = ebrains.dataproxy.api.Admin();
            %
            %   % Create a client for alternative server/base URI
            %   client = ebrains.dataproxy.api.Admin("serverUri","https://example.com:1234/api/");
            %
            %   % Create a client loading configuration options from 
            %   % JSON configuration file
            %   client = ebrains.dataproxy.api.Admin("configFile","myconfig.json");
            %
            %   % Create a client with alternative HTTPOptions and an API key
            %   client = ebrains.dataproxy.api.Admin("httpOptions",...
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

        function [code, result, response] = getBucketAcl(obj, bucket_name)
            % getBucketAcl Get Bucket Acl
            % No description provided
            %
            % Required parameters:
            %   bucket_name - No description provided, Type: string
            %
            % No optional parameters
            %
            % Responses:
            %   200: Successful Response
            %   422: Validation Error
            %
            % Returns: AnyType
            %
            % See Also: ebrains.dataproxy.models.AnyType

            arguments
              obj ebrains.dataproxy.api.Admin
              bucket_name string
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
                error("ebrains:dataproxy:api:getBucketAcl:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getBucketAcl")
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
            uri.EncodedPath = uri.EncodedPath + "/v1/admin/buckets/{bucket_name}/acl";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "bucket_name" +"}") = bucket_name;

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
            [request, httpOptions, uri] = obj.preSend("getBucketAcl", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getBucketAcl", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.dataproxy.models.AnyType(response.Body.Data);
                case 422
                    result = ebrains.dataproxy.models.HTTPValidationError(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:dataproxy:api:getBucketAcl:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getBucketAcl",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getBucketAcl method

    end %methods
end %class


