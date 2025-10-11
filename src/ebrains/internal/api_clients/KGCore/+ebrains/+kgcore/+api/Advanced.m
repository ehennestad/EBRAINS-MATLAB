classdef Advanced < ebrains.kgcore.BaseClient
    % Advanced No description provided
    %
    % Advanced Properties:
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
    % Advanced Methods:
    %
    %   Advanced - Constructor
    %   getIncomingLinks - Get incoming links for a specific instance (paginated)
    %   getInstanceScope - Get the scope for the instance by its KG-internal ID
    %   getInstancesByIdentifiers - Read instances by the given list of (external) identifiers
    %   getInstancesByIds - Bulk operation of /instances/{id} to read instances by their UUIDs
    %   getNeighbors - Get the neighborhood for the instance by its KG-internal ID
    %   getReleaseStatusByIds - Get the release status for multiple instances
    %   getSpace - 
    %   getSuggestedLinksForProperty - Returns suggestions for an instance to be linked by the given property (e.g. for the KG Editor) - and takes into account the passed payload (already chosen values, reflection on dependencies between properties - e.g. providing only parcellations for an already chosen brain atlas). Please note: This service will return released values for \&quot;additionalValue\&quot; in case a user only has minimal read rights
    %   getSuggestedLinksForProperty1 - Returns suggestions for an instance to be linked by the given property (e.g. for the KG Editor). Please note: This service will return released values for \&quot;additionalValue\&quot; in case a user only has minimal read rights
    %   getTypesByName - Returns the types according to the list of names - either with property information or without
    %   inviteUserForInstance - Create or update an invitation for the given user to review the given instance
    %   listInstancesWithInvitations - List instances with invitations
    %   listInvitations - List invitations for review for the given instance
    %   listSpaces - 
    %   myRoles - Retrieve the roles for the current user
    %   revokeUserInvitation - Revoke an invitation for the given user to review the given instance
    %
    % See Also: matlab.net.http.HTTPOptions, matlab.net.http.Credentials, 
    %   CookieJar.setCookies, ebrains.kgcore.BaseClient

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
        function obj = Advanced(options)
            % Advanced Constructor, creates a Advanced instance.
            % When called without inputs, tries to load configuration
            % options from JSON file 'ebrains.kgcore.Client.Settings.json'.
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
            %   client = ebrains.kgcore.api.Advanced();
            %
            %   % Create a client for alternative server/base URI
            %   client = ebrains.kgcore.api.Advanced("serverUri","https://example.com:1234/api/");
            %
            %   % Create a client loading configuration options from 
            %   % JSON configuration file
            %   client = ebrains.kgcore.api.Advanced("configFile","myconfig.json");
            %
            %   % Create a client with alternative HTTPOptions and an API key
            %   client = ebrains.kgcore.api.Advanced("httpOptions",...
            %       matlab.net.http.HTTPOptions("ConnectTimeout",42),...
            %       "apiKey", "ABC123");

            arguments
                options.configFile string
                options.?ebrains.kgcore.BaseClient
            end
            % Call base constructor to override any configured settings
            args = namedargs2cell(options);
            obj@ebrains.kgcore.BaseClient(args{:})
        end

        function [code, result, response] = getIncomingLinks(obj, id, stage, property, type, optionals)
            % getIncomingLinks Get incoming links for a specific instance (paginated)
            % No description provided
            %
            % Required parameters:
            %   id - No description provided, Type: string, Format: uuid
            %   stage - No description provided, Type: string
            %   property - No description provided, Type: string
            %   type - No description provided, Type: string
            %
            % Optional name-value parameters:
            %   from - No description provided, Type: int64, Format: int64
            %   size - No description provided, Type: int64, Format: int64
            %   returnTotalResults - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: PaginatedResultNormalizedJsonLd
            %
            % See Also: ebrains.kgcore.models.PaginatedResultNormalizedJsonLd

            arguments
              obj ebrains.kgcore.api.Advanced
              id string
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              property string
              type string
              optionals.from int64
              optionals.size int64
              optionals.returnTotalResults logical
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
                error("ebrains:kgcore:api:getIncomingLinks:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getIncomingLinks")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/incomingLinks";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            uri.Query(end+1) = matlab.net.QueryParameter("property", property);
            uri.Query(end+1) = matlab.net.QueryParameter("type", type);
            if isfield(optionals, "from"), uri.Query(end+1) = matlab.net.QueryParameter("from", optionals.from); end
            if isfield(optionals, "size"), uri.Query(end+1) = matlab.net.QueryParameter("size", optionals.size); end
            if isfield(optionals, "returnTotalResults"), uri.Query(end+1) = matlab.net.QueryParameter("returnTotalResults", optionals.returnTotalResults); end
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getIncomingLinks", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getIncomingLinks", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.PaginatedResultNormalizedJsonLd(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getIncomingLinks:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getIncomingLinks",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getIncomingLinks method

        function [code, result, response] = getInstanceScope(obj, id, stage, optionals)
            % getInstanceScope Get the scope for the instance by its KG-internal ID
            % No description provided
            %
            % Required parameters:
            %   id - No description provided, Type: string, Format: uuid
            %   stage - No description provided, Type: string
            %
            % Optional name-value parameters:
            %   returnPermissions - No description provided, Type: logical
            %   applyRestrictions - No description provided, Type: logical
            %
            % Responses:
            %   200: The scope of the instance
            %   509: Bandwidth Limit Exceeded
            %   404: Instance not found
            %
            % Returns: ResultScopeElement
            %
            % See Also: ebrains.kgcore.models.ResultScopeElement

            arguments
              obj ebrains.kgcore.api.Advanced
              id string
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              optionals.returnPermissions logical
              optionals.applyRestrictions logical
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
                error("ebrains:kgcore:api:getInstanceScope:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getInstanceScope")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/scope";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            if isfield(optionals, "returnPermissions"), uri.Query(end+1) = matlab.net.QueryParameter("returnPermissions", optionals.returnPermissions); end
            if isfield(optionals, "applyRestrictions"), uri.Query(end+1) = matlab.net.QueryParameter("applyRestrictions", optionals.applyRestrictions); end
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getInstanceScope", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getInstanceScope", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultScopeElement(response.Body.Data);
                case 509
                    result = ebrains.kgcore.models.ResultScopeElement(response.Body.Data);
                case 404
                    result = ebrains.kgcore.models.ResultScopeElement(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getInstanceScope:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getInstanceScope",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getInstanceScope method

        function [code, result, response] = getInstancesByIdentifiers(obj, stage, request_body, optionals)
            % getInstancesByIdentifiers Read instances by the given list of (external) identifiers
            % No description provided
            %
            % Required parameters:
            %   stage - No description provided, Type: string
            %   request_body - No description provided, Type: array
            %       Required properties in the model for this call:
            %       Optional properties in the model for this call:
            %
            % Optional name-value parameters:
            %   returnIncomingLinks - No description provided, Type: logical
            %   incomingLinksPageSize - No description provided, Type: int64, Format: int64
            %   returnPayload - No description provided, Type: logical
            %   returnPermissions - No description provided, Type: logical
            %   returnAlternatives - No description provided, Type: logical
            %   returnEmbedded - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultMapStringResultNormalizedJsonLd
            %
            % See Also: ebrains.kgcore.models.ResultMapStringResultNormalizedJsonLd

            arguments
              obj ebrains.kgcore.api.Advanced
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              request_body string
              optionals.returnIncomingLinks logical
              optionals.incomingLinksPageSize int64
              optionals.returnPayload logical
              optionals.returnPermissions logical
              optionals.returnAlternatives logical
              optionals.returnEmbedded logical
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
                error("ebrains:kgcore:api:getInstancesByIdentifiers:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getInstancesByIdentifiers")
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
                error("ebrains:kgcore:api:getInstancesByIdentifiers:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getInstancesByIdentifiers")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instancesByIdentifiers";

            % No path parameters

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            if isfield(optionals, "returnIncomingLinks"), uri.Query(end+1) = matlab.net.QueryParameter("returnIncomingLinks", optionals.returnIncomingLinks); end
            if isfield(optionals, "incomingLinksPageSize"), uri.Query(end+1) = matlab.net.QueryParameter("incomingLinksPageSize", optionals.incomingLinksPageSize); end
            if isfield(optionals, "returnPayload"), uri.Query(end+1) = matlab.net.QueryParameter("returnPayload", optionals.returnPayload); end
            if isfield(optionals, "returnPermissions"), uri.Query(end+1) = matlab.net.QueryParameter("returnPermissions", optionals.returnPermissions); end
            if isfield(optionals, "returnAlternatives"), uri.Query(end+1) = matlab.net.QueryParameter("returnAlternatives", optionals.returnAlternatives); end
            if isfield(optionals, "returnEmbedded"), uri.Query(end+1) = matlab.net.QueryParameter("returnEmbedded", optionals.returnEmbedded); end
            
            % Set JSON Body
            requiredProperties = [...
            ];
            optionalProperties = [...
            ];
            request.Body(1).Payload = request_body.getPayload(requiredProperties,optionalProperties);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getInstancesByIdentifiers", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getInstancesByIdentifiers", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultMapStringResultNormalizedJsonLd(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getInstancesByIdentifiers:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getInstancesByIdentifiers",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getInstancesByIdentifiers method

        function [code, result, response] = getInstancesByIds(obj, stage, request_body, optionals)
            % getInstancesByIds Bulk operation of /instances/{id} to read instances by their UUIDs
            % No description provided
            %
            % Required parameters:
            %   stage - No description provided, Type: string
            %   request_body - No description provided, Type: array
            %       Required properties in the model for this call:
            %       Optional properties in the model for this call:
            %
            % Optional name-value parameters:
            %   returnIncomingLinks - No description provided, Type: logical
            %   incomingLinksPageSize - No description provided, Type: int64, Format: int64
            %   returnPayload - No description provided, Type: logical
            %   returnPermissions - No description provided, Type: logical
            %   returnAlternatives - No description provided, Type: logical
            %   returnEmbedded - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultMapStringResultNormalizedJsonLd
            %
            % See Also: ebrains.kgcore.models.ResultMapStringResultNormalizedJsonLd

            arguments
              obj ebrains.kgcore.api.Advanced
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              request_body string
              optionals.returnIncomingLinks logical
              optionals.incomingLinksPageSize int64
              optionals.returnPayload logical
              optionals.returnPermissions logical
              optionals.returnAlternatives logical
              optionals.returnEmbedded logical
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
                error("ebrains:kgcore:api:getInstancesByIds:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getInstancesByIds")
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
                error("ebrains:kgcore:api:getInstancesByIds:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getInstancesByIds")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instancesByIds";

            % No path parameters

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            if isfield(optionals, "returnIncomingLinks"), uri.Query(end+1) = matlab.net.QueryParameter("returnIncomingLinks", optionals.returnIncomingLinks); end
            if isfield(optionals, "incomingLinksPageSize"), uri.Query(end+1) = matlab.net.QueryParameter("incomingLinksPageSize", optionals.incomingLinksPageSize); end
            if isfield(optionals, "returnPayload"), uri.Query(end+1) = matlab.net.QueryParameter("returnPayload", optionals.returnPayload); end
            if isfield(optionals, "returnPermissions"), uri.Query(end+1) = matlab.net.QueryParameter("returnPermissions", optionals.returnPermissions); end
            if isfield(optionals, "returnAlternatives"), uri.Query(end+1) = matlab.net.QueryParameter("returnAlternatives", optionals.returnAlternatives); end
            if isfield(optionals, "returnEmbedded"), uri.Query(end+1) = matlab.net.QueryParameter("returnEmbedded", optionals.returnEmbedded); end
            
            % Set JSON Body
            requiredProperties = [...
            ];
            optionalProperties = [...
            ];
            request.Body(1).Payload = request_body.getPayload(requiredProperties,optionalProperties);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getInstancesByIds", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getInstancesByIds", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultMapStringResultNormalizedJsonLd(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getInstancesByIds:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getInstancesByIds",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getInstancesByIds method

        function [code, result, response] = getNeighbors(obj, id, stage)
            % getNeighbors Get the neighborhood for the instance by its KG-internal ID
            % No description provided
            %
            % Required parameters:
            %   id - No description provided, Type: string, Format: uuid
            %   stage - No description provided, Type: string
            %
            % No optional parameters
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultGraphEntity
            %
            % See Also: ebrains.kgcore.models.ResultGraphEntity

            arguments
              obj ebrains.kgcore.api.Advanced
              id string
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
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
                error("ebrains:kgcore:api:getNeighbors:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getNeighbors")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/neighbors";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getNeighbors", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getNeighbors", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultGraphEntity(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getNeighbors:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getNeighbors",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getNeighbors method

        function [code, result, response] = getReleaseStatusByIds(obj, releaseTreeScope, request_body)
            % getReleaseStatusByIds Get the release status for multiple instances
            % No description provided
            %
            % Required parameters:
            %   releaseTreeScope - No description provided, Type: string
            %   request_body - No description provided, Type: array
            %       Required properties in the model for this call:
            %       Optional properties in the model for this call:
            %
            % No optional parameters
            %
            % Responses:
            %   404: Instance not found
            %   200: The release status of the instance
            %
            % Returns: ResultMapUUIDResultReleaseStatus
            %
            % See Also: ebrains.kgcore.models.ResultMapUUIDResultReleaseStatus

            arguments
              obj ebrains.kgcore.api.Advanced
              releaseTreeScope string { mustBeMember(releaseTreeScope,["TOP_INSTANCE_ONLY","CHILDREN_ONLY","CHILDREN_ONLY_RESTRICTED"]) }
              request_body string
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
                error("ebrains:kgcore:api:getReleaseStatusByIds:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getReleaseStatusByIds")
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
                error("ebrains:kgcore:api:getReleaseStatusByIds:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getReleaseStatusByIds")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instancesByIds/release/status";

            % No path parameters

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("releaseTreeScope", releaseTreeScope);
            
            % Set JSON Body
            requiredProperties = [...
            ];
            optionalProperties = [...
            ];
            request.Body(1).Payload = request_body.getPayload(requiredProperties,optionalProperties);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getReleaseStatusByIds", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getReleaseStatusByIds", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 404
                    result = ebrains.kgcore.models.ResultMapUUIDResultReleaseStatus(response.Body.Data);
                case 200
                    result = ebrains.kgcore.models.ResultMapUUIDResultReleaseStatus(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getReleaseStatusByIds:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getReleaseStatusByIds",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getReleaseStatusByIds method

        function [code, result, response] = getSpace(obj, space, optionals)
            % getSpace No summary provided
            % No description provided
            %
            % Required parameters:
            %   space - The space to be read or \"myspace\" for your private space, Type: string
            %
            % Optional name-value parameters:
            %   permissions - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultSpaceInformation
            %
            % See Also: ebrains.kgcore.models.ResultSpaceInformation

            arguments
              obj ebrains.kgcore.api.Advanced
              space string
              optionals.permissions logical
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
                error("ebrains:kgcore:api:getSpace:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getSpace")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/spaces/{space}";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "space" +"}") = space;

            % Set query parameters
            if isfield(optionals, "permissions"), uri.Query(end+1) = matlab.net.QueryParameter("permissions", optionals.permissions); end
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getSpace", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getSpace", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultSpaceInformation(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getSpace:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getSpace",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getSpace method

        function [code, result, response] = getSuggestedLinksForProperty(obj, stage, property, id, request_body, optionals)
            % getSuggestedLinksForProperty Returns suggestions for an instance to be linked by the given property (e.g. for the KG Editor) - and takes into account the passed payload (already chosen values, reflection on dependencies between properties - e.g. providing only parcellations for an already chosen brain atlas). Please note: This service will return released values for \"additionalValue\" in case a user only has minimal read rights
            % No description provided
            %
            % Required parameters:
            %   stage - No description provided, Type: string
            %   property - No description provided, Type: string
            %   id - No description provided, Type: string, Format: uuid
            %   request_body - No description provided, Type: ebrains.kgcore.JSONMapperMap
            %       Required properties in the model for this call:
            %       Optional properties in the model for this call:
            %           id
            %           empty
            %
            % Optional name-value parameters:
            %   sourceType - The source type for which the given property shall be evaluated. If not provided, the API tries to figure out the type by analyzing the type of the root object originating from the payload. Please note, that this parameter is mandatory for embedded structures., Type: string
            %   targetType - The target type of the suggestions. If not provided, suggestions of all possible target types will be returned., Type: string
            %   search - No description provided, Type: string
            %   from - No description provided, Type: int64, Format: int64
            %   size - No description provided, Type: int64, Format: int64
            %   returnTotalResults - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultSuggestionResult
            %
            % See Also: ebrains.kgcore.models.ResultSuggestionResult

            arguments
              obj ebrains.kgcore.api.Advanced
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              property string
              id string
              request_body ebrains.kgcore.JSONMapperMap
              optionals.sourceType string
              optionals.targetType string
              optionals.search string
              optionals.from int64
              optionals.size int64
              optionals.returnTotalResults logical
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
                error("ebrains:kgcore:api:getSuggestedLinksForProperty:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getSuggestedLinksForProperty")
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
                error("ebrains:kgcore:api:getSuggestedLinksForProperty:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getSuggestedLinksForProperty")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/suggestedLinksForProperty";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            uri.Query(end+1) = matlab.net.QueryParameter("property", property);
            if isfield(optionals, "sourceType"), uri.Query(end+1) = matlab.net.QueryParameter("sourceType", optionals.sourceType); end
            if isfield(optionals, "targetType"), uri.Query(end+1) = matlab.net.QueryParameter("targetType", optionals.targetType); end
            if isfield(optionals, "search"), uri.Query(end+1) = matlab.net.QueryParameter("search", optionals.search); end
            if isfield(optionals, "from"), uri.Query(end+1) = matlab.net.QueryParameter("from", optionals.from); end
            if isfield(optionals, "size"), uri.Query(end+1) = matlab.net.QueryParameter("size", optionals.size); end
            if isfield(optionals, "returnTotalResults"), uri.Query(end+1) = matlab.net.QueryParameter("returnTotalResults", optionals.returnTotalResults); end
            
            % Set JSON Body
            requiredProperties = [...
            ];
            optionalProperties = [...
                "id",...
                "empty",...
            ];
            request.Body(1).Payload = request_body.getPayload(requiredProperties,optionalProperties);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getSuggestedLinksForProperty", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getSuggestedLinksForProperty", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultSuggestionResult(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getSuggestedLinksForProperty:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getSuggestedLinksForProperty",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getSuggestedLinksForProperty method

        function [code, result, response] = getSuggestedLinksForProperty1(obj, stage, id, property, optionals)
            % getSuggestedLinksForProperty1 Returns suggestions for an instance to be linked by the given property (e.g. for the KG Editor). Please note: This service will return released values for \"additionalValue\" in case a user only has minimal read rights
            % No description provided
            %
            % Required parameters:
            %   stage - No description provided, Type: string
            %   id - No description provided, Type: string, Format: uuid
            %   property - No description provided, Type: string
            %
            % Optional name-value parameters:
            %   sourceType - The source type for which the given property shall be evaluated. If not provided, the API tries to figure out the type by analyzing the type of the root object of the persisted instance. Please note, that this parameter is mandatory for embedded structures., Type: string
            %   targetType - The target type of the suggestions. If not provided, suggestions of all possible target types will be returned., Type: string
            %   search - No description provided, Type: string
            %   from - No description provided, Type: int64, Format: int64
            %   size - No description provided, Type: int64, Format: int64
            %   returnTotalResults - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultSuggestionResult
            %
            % See Also: ebrains.kgcore.models.ResultSuggestionResult

            arguments
              obj ebrains.kgcore.api.Advanced
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              id string
              property string
              optionals.sourceType string
              optionals.targetType string
              optionals.search string
              optionals.from int64
              optionals.size int64
              optionals.returnTotalResults logical
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
                error("ebrains:kgcore:api:getSuggestedLinksForProperty1:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getSuggestedLinksForProperty1")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/suggestedLinksForProperty";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            uri.Query(end+1) = matlab.net.QueryParameter("property", property);
            if isfield(optionals, "sourceType"), uri.Query(end+1) = matlab.net.QueryParameter("sourceType", optionals.sourceType); end
            if isfield(optionals, "targetType"), uri.Query(end+1) = matlab.net.QueryParameter("targetType", optionals.targetType); end
            if isfield(optionals, "search"), uri.Query(end+1) = matlab.net.QueryParameter("search", optionals.search); end
            if isfield(optionals, "from"), uri.Query(end+1) = matlab.net.QueryParameter("from", optionals.from); end
            if isfield(optionals, "size"), uri.Query(end+1) = matlab.net.QueryParameter("size", optionals.size); end
            if isfield(optionals, "returnTotalResults"), uri.Query(end+1) = matlab.net.QueryParameter("returnTotalResults", optionals.returnTotalResults); end
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getSuggestedLinksForProperty1", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getSuggestedLinksForProperty1", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultSuggestionResult(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getSuggestedLinksForProperty1:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getSuggestedLinksForProperty1",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getSuggestedLinksForProperty1 method

        function [code, result, response] = getTypesByName(obj, stage, request_body, optionals)
            % getTypesByName Returns the types according to the list of names - either with property information or without
            % No description provided
            %
            % Required parameters:
            %   stage - No description provided, Type: string
            %   request_body - No description provided, Type: array
            %       Required properties in the model for this call:
            %       Optional properties in the model for this call:
            %
            % Optional name-value parameters:
            %   withProperties - No description provided, Type: logical
            %   withIncomingLinks - No description provided, Type: logical
            %   space - The space by which the types should be filtered or \"myspace\" for your private space., Type: string
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultMapStringResultTypeInformation
            %
            % See Also: ebrains.kgcore.models.ResultMapStringResultTypeInformation

            arguments
              obj ebrains.kgcore.api.Advanced
              stage string { mustBeMember(stage,["IN_PROGRESS","RELEASED"]) }
              request_body string
              optionals.withProperties logical
              optionals.withIncomingLinks logical
              optionals.space string
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
                error("ebrains:kgcore:api:getTypesByName:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getTypesByName")
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
                error("ebrains:kgcore:api:getTypesByName:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' and 'application/x-www-form-urlencoded' MediaTypes.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","getTypesByName")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/typesByName";

            % No path parameters

            % Set query parameters
            uri.Query(end+1) = matlab.net.QueryParameter("stage", stage);
            if isfield(optionals, "withProperties"), uri.Query(end+1) = matlab.net.QueryParameter("withProperties", optionals.withProperties); end
            if isfield(optionals, "withIncomingLinks"), uri.Query(end+1) = matlab.net.QueryParameter("withIncomingLinks", optionals.withIncomingLinks); end
            if isfield(optionals, "space"), uri.Query(end+1) = matlab.net.QueryParameter("space", optionals.space); end
            
            % Set JSON Body
            requiredProperties = [...
            ];
            optionalProperties = [...
            ];
            %request.Body(1).Payload = request_body.getPayload(requiredProperties,optionalProperties);
            request.Body(1).Data = cellstr(request_body);

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("getTypesByName", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("getTypesByName", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultMapStringResultTypeInformation(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:getTypesByName:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","getTypesByName",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % getTypesByName method

        function [code, result, response] = inviteUserForInstance(obj, id, userId)
            % inviteUserForInstance Create or update an invitation for the given user to review the given instance
            % No description provided
            %
            % Required parameters:
            %   id - No description provided, Type: string, Format: uuid
            %   userId - No description provided, Type: string, Format: uuid
            %
            % No optional parameters
            %
            % Responses:
            %   200: OK
            %
            % Returns: 
            %
            % See Also: ebrains.kgcore.models.

            arguments
              obj ebrains.kgcore.api.Advanced
              id string
              userId string
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % No return content type specified, defaulting to JSON
            request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            
            % No body input, so no need to check its content type
            
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/invitedUsers/{userId}";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;
            uri.Path(uri.Path == "{" + "userId" +"}") = userId;

            % No query parameters
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("inviteUserForInstance", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("inviteUserForInstance", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = response.Body.Data;
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:inviteUserForInstance:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","inviteUserForInstance",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % inviteUserForInstance method

        function [code, result, response] = listInstancesWithInvitations(obj)
            % listInstancesWithInvitations List instances with invitations
            % No description provided
            %
            % No required parameters
            %
            % No optional parameters
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultListUUID
            %
            % See Also: ebrains.kgcore.models.ResultListUUID

            arguments
              obj ebrains.kgcore.api.Advanced
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
                error("ebrains:kgcore:api:listInstancesWithInvitations:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","listInstancesWithInvitations")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instancesWithInvitations";

            % No path parameters

            % No query parameters
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("listInstancesWithInvitations", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("listInstancesWithInvitations", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultListUUID(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:listInstancesWithInvitations:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","listInstancesWithInvitations",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % listInstancesWithInvitations method

        function [code, result, response] = listInvitations(obj, id)
            % listInvitations List invitations for review for the given instance
            % No description provided
            %
            % Required parameters:
            %   id - No description provided, Type: string, Format: uuid
            %
            % No optional parameters
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultListString
            %
            % See Also: ebrains.kgcore.models.ResultListString

            arguments
              obj ebrains.kgcore.api.Advanced
              id string
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
                error("ebrains:kgcore:api:listInvitations:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","listInvitations")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/invitedUsers";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;

            % No query parameters
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("listInvitations", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("listInvitations", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultListString(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:listInvitations:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","listInvitations",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % listInvitations method

        function [code, result, response] = listSpaces(obj, optionals)
            % listSpaces No summary provided
            % No description provided
            %
            % No required parameters
            %
            % Optional name-value parameters:
            %   from - No description provided, Type: int64, Format: int64
            %   size - No description provided, Type: int64, Format: int64
            %   returnTotalResults - No description provided, Type: logical
            %   permissions - No description provided, Type: logical
            %
            % Responses:
            %   200: OK
            %
            % Returns: PaginatedResultSpaceInformation
            %
            % See Also: ebrains.kgcore.models.PaginatedResultSpaceInformation

            arguments
              obj ebrains.kgcore.api.Advanced
              optionals.from int64
              optionals.size int64
              optionals.returnTotalResults logical
              optionals.permissions logical
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
                error("ebrains:kgcore:api:listSpaces:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","listSpaces")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/spaces";

            % No path parameters

            % Set query parameters
            if isfield(optionals, "from"), uri.Query(end+1) = matlab.net.QueryParameter("from", optionals.from); end
            if isfield(optionals, "size"), uri.Query(end+1) = matlab.net.QueryParameter("size", optionals.size); end
            if isfield(optionals, "returnTotalResults"), uri.Query(end+1) = matlab.net.QueryParameter("returnTotalResults", optionals.returnTotalResults); end
            if isfield(optionals, "permissions"), uri.Query(end+1) = matlab.net.QueryParameter("permissions", optionals.permissions); end
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("listSpaces", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("listSpaces", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.PaginatedResultSpaceInformation(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:listSpaces:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","listSpaces",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % listSpaces method

        function [code, result, response] = myRoles(obj)
            % myRoles Retrieve the roles for the current user
            % No description provided
            %
            % No required parameters
            %
            % No optional parameters
            %
            % Responses:
            %   200: OK
            %
            % Returns: ResultUserWithRoles
            %
            % See Also: ebrains.kgcore.models.ResultUserWithRoles

            arguments
              obj ebrains.kgcore.api.Advanced
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
                error("ebrains:kgcore:api:myRoles:UnsupportedMediaType","Generated OpenAPI Classes only support 'application/json' MediaType.\n" + ...
                    "Operation '%s' does not support this. It may be possible to call this operation by first editing the generated code.","myRoles")
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/users/me/roles";

            % No path parameters

            % No query parameters
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("myRoles", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("myRoles", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = ebrains.kgcore.models.ResultUserWithRoles(response.Body.Data);
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:myRoles:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","myRoles",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % myRoles method

        function [code, result, response] = revokeUserInvitation(obj, id, userId)
            % revokeUserInvitation Revoke an invitation for the given user to review the given instance
            % No description provided
            %
            % Required parameters:
            %   id - No description provided, Type: string, Format: uuid
            %   userId - No description provided, Type: string, Format: uuid
            %
            % No optional parameters
            %
            % Responses:
            %   200: OK
            %
            % Returns: 
            %
            % See Also: ebrains.kgcore.models.

            arguments
              obj ebrains.kgcore.api.Advanced
              id string
              userId string
            end

            % Create the request object
            request = matlab.net.http.RequestMessage();
            
            % No return content type specified, defaulting to JSON
            request.Header(end+1) = matlab.net.http.field.AcceptField('application/json');
            
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
                uri = matlab.net.URI("https://core.kg.ebrains.eu");
            end
            % Append the operation end-point
            uri.EncodedPath = uri.EncodedPath + "/v3/instances/{id}/invitedUsers/{userId}";

            % Substitute path parameters
            uri.Path(uri.Path == "{" + "id" +"}") = id;
            uri.Path(uri.Path == "{" + "userId" +"}") = userId;

            % No query parameters
            
            % No JSON body parameters

            % No form body parameters

            % Configure Authentication
            authNames = [...
                "Authorization", ...
                "Client-Authorization", ...
            ];  
            [request, httpOptions, uri] = obj.requestAuth(authNames, request, httpOptions, uri);

            % Add cookies if set
            request = obj.applyCookies(request, uri);

            % Call preSend
            [request, httpOptions, uri] = obj.preSend("revokeUserInvitation", request, httpOptions, uri);

            % Perform the request
            [response, ~, history] = send(request, uri, httpOptions);

            % Handle cookies if set
            obj.setCookies(history);

            % Call postSend
            response = obj.postSend("revokeUserInvitation", response, request, uri, httpOptions);

            % Handle response
            code = response.StatusCode;
            switch (code)
                case 200
                    result = response.Body.Data;
                otherwise % Unexpected output, not declared in spec
                    % Any response in the OK range will not throw a warning
                    if (int32(response.StatusCode) < 200 || int32(response.StatusCode) >= 300)
                        % Others will throw a warning
                        warning("ebrains:kgcore:api:revokeUserInvitation:UndocumentedResponse","Operation '%s' returned an undocumented response code '%d'.\n" + ...
                            "Response Body is returned as raw data.","revokeUserInvitation",code);
                    end
                    % Return the raw body data
                    result = response.Body.Data;
            end
        
        end % revokeUserInvitation method

    end %methods
end %class


