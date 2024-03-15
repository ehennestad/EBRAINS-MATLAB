classdef AuthenticationClient < handle
% AuthenticationClient - Client for Device Authentication Flow
%
%   USAGE:
%       authClient = ebrains.iam.AuthenticationClient.instance() creates a
%           client or retrieves an existing (persistent) client
%
%       authClient.fetchToken() redirects to the browser for user to grant
%           permissions

% Todo: Implement the refresh of access token

% Details on the Device Authentication Flow
% https://wiki.ebrains.eu/bin/view/Collabs/the-collaboratory/Documentation%20IAM/FAQ/Using%20the%20Device%20Authentication%20Flow/

    
    properties (Constant)
        OIDC_CLIENT_NAME = "sharebrain"
    end

    properties
        Scope = [ enumeration('ebrains.iam.enum.Scope').Name ]
    end
    
    properties (Dependent, SetAccess = private)
        AccessToken
    end

    properties (Dependent)
        ExpiresIn
    end

    properties (Access = private)
        OpenIdConfig
        AccessToken_ (1,1) string = missing
        RefreshToken (1,1) string
        AccessTokenExpiresAt
        RefreshTokenExpiresAt
    end

    properties (Constant, Access = private)
        SINGLETON_NAME = "IAM_Authentication_Client"

        IAM_BASE_URL = ...
            "https://iam.ebrains.eu/auth/realms/hbp/"
        
        WELL_KNOWN_CONFIGURATION_ENDPOINT = ...
            ".well-known/openid-configuration"
    end
    
    methods (Access = private)
        function obj = AuthenticationClient(obj)
            obj.initOidc()
        end
    end

    methods
        function opts = getWebOptions(obj, opts)
            arguments
                obj
                opts weboptions = weboptions
            end

            opts.HeaderFields = [ opts.HeaderFields, ...
                "Authorization", sprintf("Bearer %s", obj.AccessToken)];
        end

        function fetchToken(obj)
        % fetchToken - Fetch token


            % openid-connect/auth/device
            endpointUrl = obj.OpenIdConfig.device_authorization_endpoint;
            
            responseDevice = webwrite(endpointUrl, ...
                'client_id', obj.OIDC_CLIENT_NAME, ...
                'scope', strjoin( obj.Scope, " ") );

            message = "Redirecting to web browser to authenticate...";
            f = msgbox(message, "Authenticating...");
            f.Children(1).Visible = 'off';
            pause(1)
            
            % Open browser
            web(responseDevice.verification_uri_complete)
            
            pause(1)
            message = "Press OK to continue.";
            f.Children(1).Visible = 'on';
            f.Children(2).Children(1).String = message;
            f.Children(2).Children(1).HorizontalAlignment = "left";
            uiwait(f)
            delete(f)

            % openid-connect/token
            tokenResponse = webwrite(obj.OpenIdConfig.token_endpoint, ...
                "grant_type", "urn:ietf:params:oauth:grant-type:device_code", ...
                "client_id", obj.OIDC_CLIENT_NAME,...
                "device_code", responseDevice.device_code ...
                );
            
            obj.AccessToken_ = tokenResponse.access_token;
            obj.RefreshToken = tokenResponse.refresh_token;
            
            obj.AccessTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.expires_in);
    
            obj.RefreshTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.refresh_expires_in);
        end
    end

    methods
        function remainingTime = get.ExpiresIn(obj)
            if isempty(obj.AccessTokenExpiresAt)
                remainingTime = NaT;
            else
                currentTime = datetime("now");

                remainingTime = obj.AccessTokenExpiresAt - currentTime;
            end
        end

        function accessToken = get.AccessToken(obj)
            if ismissing(obj.AccessToken_)
                obj.fetchToken()
            end
            accessToken = obj.AccessToken_;
        end
    end

    methods (Access = private)
        function initOidc(obj)
        % initOidc - Get openID configurations
            obj.OpenIdConfig = ...
                webread(obj.IAM_BASE_URL + obj.WELL_KNOWN_CONFIGURATION_ENDPOINT);
        end

    end

    methods (Static)
        function obj = instance()
        %instance - Return a singleton instance of the AuthenticationClient

        %   Note: to achieve persistent singleton instance that survives a 
        %   clear all statement, the singleton instance is stored in the 
        %   graphics root object's UserData property. 
        %   Open question: Are there better ways to do this?

            authClientObject = [];

            className = string( mfilename('class') );
            singletonName = eval( className + "." + "SINGLETON_NAME" );

            % % singletonName = matlab.lang.makeValidName(className, ...
            % %     'ReplacementStyle', 'underscore');
            
            rootUserData = get(0, 'UserData');
            if isstruct(rootUserData)
                if isfield(rootUserData, 'SingletonInstances')
                    if isfield(rootUserData.SingletonInstances, singletonName)
                        authClientObject = rootUserData.SingletonInstances.(singletonName);
                    end
                end
            end

            % - Construct the client if singleton instance is not present
            if isempty(authClientObject)
                authClientObject = ebrains.iam.AuthenticationClient();
                
                rootUserData.SingletonInstances.(singletonName) = authClientObject;
                set(0, 'UserData', rootUserData)
            end
        
            % - Return the instance
            obj = authClientObject;
        end
    end
end