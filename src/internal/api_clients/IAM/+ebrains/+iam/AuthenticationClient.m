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

            % Try to get from secrets
            if exist("isSecret", "file")
                if isSecret('EBRAINS_TOKEN')
                    obj.AccessToken_ = getSecret('EBRAINS_TOKEN');
                    obj.decodeTokenExpiryTime()
                    return
                end
            end

            % Try to get from env
            if isenv('EBRAINS_TOKEN')
                obj.AccessToken_ = getenv('EBRAINS_TOKEN');
                obj.decodeTokenExpiryTime()
            end
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

        function authField = getAuthHeaderField(obj)
            authField = matlab.net.http.field.AuthorizationField(...
                'Authorization', sprintf('Bearer %s', obj.AccessToken));
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
            reformatMessageBoxBeforeRedirecting(f)
            pause(1)
            
            % Open browser
            web(responseDevice.verification_uri_complete)
            
            pause(1)
            reformatMessageBoxAfterRedirecting(f)
            uiwait(f)
            
            % openid-connect/token
            try
                tokenResponse = webwrite(obj.OpenIdConfig.token_endpoint, ...
                    "grant_type", "urn:ietf:params:oauth:grant-type:device_code", ...
                    "client_id", obj.OIDC_CLIENT_NAME,...
                    "device_code", responseDevice.device_code ...
                    );

                showSuccess(f)
            catch ME
                delete(f)
                titleMessage = "Authentication failed";

                switch ME.identifier
                    case 'MATLAB:webservices:HTTP400StatusCodeError'
                        errorMessage = "Make sure the log in to EBRAINS in your web browser and grant access rights to SHAREbrain before pressing the continue button.";
                        errordlg(errorMessage, titleMessage)
                        throwAsCaller(ME) 
                    otherwise
                        errordlg(ME.message, titleMessage)
                        throwAsCaller(ME) 
                end
            end
            
            obj.AccessToken_ = tokenResponse.access_token;
            obj.RefreshToken = tokenResponse.refresh_token;
            
            obj.AccessTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.expires_in);
    
            obj.RefreshTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.refresh_expires_in);
        end
        
        function refreshToken(obj)
            % refreshToken - Refresh the access token using the refresh token
        
            % Check if refresh token exists
            if isempty(obj.RefreshToken)
                error("No refresh token available. Please authenticate first.");
            end
        
            try
                % Request a new access token using the refresh token
                tokenResponse = webwrite(obj.OpenIdConfig.token_endpoint, ...
                    "grant_type", "refresh_token", ...
                    "client_id", obj.OIDC_CLIENT_NAME, ...
                    "refresh_token", obj.RefreshToken ...
                );
        
                % Update object properties with new token values
                obj.AccessToken_ = tokenResponse.access_token;
                obj.RefreshToken = tokenResponse.refresh_token;
        
                obj.AccessTokenExpiresAt = ...
                    datetime("now") + seconds(tokenResponse.expires_in);
        
                obj.RefreshTokenExpiresAt = ...
                    datetime("now") + seconds(tokenResponse.refresh_expires_in);
        
                % Log success
                disp("Token refreshed successfully.");
        
            catch ME
                titleMessage = "Token Refresh Failed";
                switch ME.identifier
                    case 'MATLAB:webservices:HTTP400StatusCodeError'
                        errorMessage = "The refresh token is invalid or expired. Please reauthenticate.";
                        errordlg(errorMessage, titleMessage);
                        throwAsCaller(ME);
                    otherwise
                        errordlg(ME.message, titleMessage);
                        throwAsCaller(ME);
                end
            end
        end

        function tf = hasActiveToken(obj)
            tf = false;
            if ~ismissing(obj.AccessToken_)
                tf = obj.ExpiresIn > seconds(0);
                if obj.ExpiresIn < seconds(3600)
                    warning("EBRAINS Access token expires in %d minutes", round(seconds(obj.ExpiresIn)/60))
                end
            end
        end
    
        function copyTokenToClipboard(obj)
            clipboard("copy", obj.AccessToken_)
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
        
        function decodeTokenExpiryTime(obj)
            obj.AccessTokenExpiresAt = ...
                ebrains.internal.get_token_expiration(obj.AccessToken_);
            obj.AccessTokenExpiresAt.TimeZone = '';
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

function showSuccess(hFigure)
    message = "Access token successfully retrieved!";
    hFigure.Children(2).Children(1).String = message;
    pause(1.5)
    delete(hFigure)
end

function onContinuePressed(hFigure)
    hFigure.Children(1).Visible = 'off';
    message = "Please wait while retrieving your access token...";

    hFigure.Children(2).Children(1).String = message;
    centerHorizontally(hFigure, hFigure.Children(2).Children(1) )
    hFigure.Children(2).Children(1).Position(2) = hFigure.Children(2).Children(1).Position(2)-8;
    uiresume(hFigure)
end

function reformatMessageBoxBeforeRedirecting(hFigure)
    hFigure.Position = hFigure.Position + [-50, 0, 100,14];
    hFigure.Children(1).Visible = 'off';
    hFigure.Children(1).FontSize = 14;
    centerHorizontally(hFigure, hFigure.Children(1) )
    hFigure.Children(2).Children(1).FontSize = 14;
    hFigure.Children(2).Children(1).Position(2) = hFigure.Children(2).Children(1).Position(2)+5;
    centerHorizontally(hFigure, hFigure.Children(2).Children(1) )
end

function reformatMessageBoxAfterRedirecting(hFigure)
    message = "Press Continue to complete authentication.";
    hFigure.Children(1).Visible = 'on';
    hFigure.Children(1).String = 'Continue';
    hFigure.Children(1).Callback = @(s,e,h) onContinuePressed(hFigure);

    %f.Children(1).Position(3:4) = [80,30];
    hFigure.Children(1).Position(3:4) = [80, 22];
    centerHorizontally(hFigure, hFigure.Children(1) )
    hFigure.Children(1).Position(2) = hFigure.Children(1).Position(2) + 4;

    hFigure.Children(2).Children(1).String = message;
    hFigure.Children(2).Children(1).HorizontalAlignment = "left";
    centerHorizontally(hFigure, hFigure.Children(2).Children(1) )
    hFigure.Children(2).Children(1).Position(2) = hFigure.Children(2).Children(1).Position(2)+8;
end

function centerHorizontally(hFigure, component)
    W = hFigure.Position(3);
    componentPosition = component.Position;
    if numel(componentPosition)==3
        componentPosition(3:4) = component.Extent(3:4);
    end
    
    xLeft = W/2 - componentPosition(3)/2;
    component.Position(1)=xLeft;
end
