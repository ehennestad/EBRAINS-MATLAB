classdef (Abstract) BaseClient < handle & matlab.mixin.CustomDisplay
    % BASECLIENT Base class for RESTful ebrains.collaboratory services.
    % Includes common initialization and authentication code. Authentication
    % code may have to be manually updated after code generation.
    %
    % This class cannot be instantiated directly, work with classes derived
    % from it to actually interact with the RESTful service.

    % This file is automatically generated using OpenAPI
    % Specification version: 1.0
    % MATLAB Generator for OpenAPI version: 1.0.9
    
    
    
    properties
        % Base URI to use when calling the API. Allows using a different server
        % than specified in the original API spec.
        serverUri matlab.net.URI
        
        % HTTPOptions used by all requests.
        httpOptions = matlab.net.http.HTTPOptions;

        % If operation supports multiple authentication methods, specified which
        % method to prefer.
        preferredAuthMethod = string.empty;
        
        % If Bearer token authentication is used, the token can be supplied 
        % here. Note the token is only used if operations are called for which
        % the API explicitly specified that Bearer authentication is supported.
        % If this has not been specified in the spec but most operations do 
        % require Bearer authentication consider adding the relevant header to
        % all requests in the preSend method.
        bearerToken = string.empty;

        % If API key authentication is used, the key can be supplied here. 
        % Note the key is only used if operations are called for which
        % the API explicitly specified that API key authentication is supported.
        % If this has not been specified in the spec but most operations do 
        % require API key authentication consider adding the API key to all
        % requests in the preSend method.
        apiKey = string.empty;

        % If Basic or Digest authentication is supported username/password
        % credentials can be supplied here as matlab.net.http.Credentials. Note 
        % these are only actively used if operations are called for which the 
        % API spec has specified they require Basic authentication. If this has
        % not been set specified in the spec but most operations do require
        % Basic authentication consider setting the Credentials property in the
        % httpOptions rather than through httpCredentials.
        httpCredentials = matlab.net.http.Credentials.empty;
    end

    properties (Constant)
        % Cookie jar. The cookie jar is shared across all Api classes in the 
        % same package. All responses are automatically parsed for Set-Cookie
        % headers and cookies are automatically added to the jar. Similarly
        % cookies are added to outgoing requests if there are matching cookies 
        % in the jar for the given request. Cookies can also be added manually
        % by calling the setCookies method on the cookies property. The cookie
        % jar is also saved to disk (cookies.mat in the same directory as 
        % BaseClient) and reloaded in new MATLAB sessions.
        cookies = ebrains.collaboratory.CookieJar(fileparts(mfilename('fullpath')));
    end

    methods
        function obj = BaseClient(options)
            % ebrains.collaboratory.BaseClient constructor to be called from 
            % derived classes to allow setting properties upon construction
            arguments
                options.configFile string
                options.?ebrains.collaboratory.BaseClient
            end
            % If there no specific file supplied as input but there is a 
            % JSON file for the package, use that file
            if ~isfield(options,"configFile") && isfile(which("ebrains.collaboratory.Client.Settings.json"))
                options.configFile = which("ebrains.collaboratory.Client.Settings.json");
            end
            % If there is a specific configuration file supplied as input
            if isfield(options,"configFile")
                % Load configuration from configuration file
                obj.loadConfigFile(options.configFile);
                % Remove the field to continue overloading any further options
                options = rmfield(options,'configFile');
            end
            % Set/override other parameters provided as input
            for p = string(fieldnames(options))'
                obj.(p) = options.(p);
            end
        end
    end % public methods

    methods (Access=protected)

        function request = applyCookies(obj, request, uri)
            c = obj.cookies.getCookies(uri);
            if ~isempty(c)
                request = request.addFields(matlab.net.http.field.CookieField(c));
            end
        end

        function setCookies(obj, history)
            cookieInfos = matlab.net.http.CookieInfo.collectFromLog(history);
            if ~isempty(cookieInfos)
                obj.cookies.setCookies(cookieInfos);
            end
        end
        
        % No authentication methods found in spec, requestAuth was not generated
        
        % No OAuth authentication found in spec, getOAuthToken was not generated

        function [request, httpOptions, uri] = preSend(obj, operationId, request, httpOptions, uri) %#ok<INUSL> 
            % PRESEND is called by every operation right before sending the
            % request. This method can for example be customized to add a
            % header to all (or most) requests if needed. 
            %
            % If the requests of only a few operations need to be customized
            % it is recommended to modify the generated operation methods
            % in the Api classes themselves rather than modifying preSend.
            %
            % By default the generated preSend does not do anything, it just
            % returns the inputs as is.

            authField = matlab.net.http.field.AuthorizationField(...
                'Authorization', sprintf('Bearer %s', obj.bearerToken));
            request.Header = request.Header.addFields(authField);
        end

        function response = postSend(obj, operationId, response, request, uri, httpOptions)  %#ok<INUSD,INUSL>
            % POSTSEND is called by every operation right after sending the
            % request. This method can for example be customized to add
            % customized error handling if the API responds to errors in a
            % consistent way.
            %
            % If the responses of only a few operations need to be customized
            % it is recommended to modify the generated operation methods
            % in the Api classes themselves rather than modifying postSend.
            %
            % By default the generated postSend does not do anything, it just
            % returns the response as is.
        end

        function propgrp = getPropertyGroups(obj)
            % Redact properties such that tokens, etc. do not show up
            % in Command Window output
            hide = ["bearerToken", "apiKey","httpCredentials"];
            propgrp = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            for h = hide
                if isempty(obj.(h))
                    propgrp.PropertyList.(h) = '<unset>';
                else
                    propgrp.PropertyList.(h) = '<redacted>';
                end
            end
        end
    end % protected methods

    methods (Access=private)
        function loadConfigFile(obj, filename)
            % Loads client and http properties from a JSON file
            settings = jsondecode(fileread(filename));
            for f = string(fieldnames(settings))'
                switch f
                    case 'httpOptions'
                        args = namedargs2cell(settings.httpOptions);
                        obj.httpOptions = matlab.net.http.HTTPOptions(args{:});
                    case 'httpCredentials'
                        args = namedargs2cell(settings.httpCredentials);
                        obj.httpCredentials = matlab.net.http.Credentials(args{:});
                    case 'cookies'
                        obj.cookies.load(settings.cookies.path);
                    otherwise
                        obj.(f) = settings.(f);
                end
            end
        end
    end % private methods
end %class
