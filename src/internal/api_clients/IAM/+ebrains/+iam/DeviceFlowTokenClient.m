classdef DeviceFlowTokenClient < ebrains.iam.OidcTokenClient
% DeviceFlowTokenClient - Client for OIDC Device Authentication Flow
%
%   This client implements the OAuth 2.0 Device Authorization Grant flow
%   for authenticating with EBRAINS IAM.
%
%   USAGE:
%       authClient = ebrains.iam.DeviceFlowTokenClient.instance() creates a
%           client or retrieves an existing (persistent) client
%
%       authClient.fetchToken() redirects to the browser for user to grant
%           permissions
%
%   See also: ebrains.iam.OidcTokenClient

% Details on the Device Authentication Flow
% https://wiki.ebrains.eu/bin/view/Collabs/the-collaboratory/Documentation%20IAM/FAQ/Using%20the%20Device%20Authentication%20Flow/

    properties (Constant)
        FLOW_NAME = "Device Flow"
    end

    properties (Constant, Access = private)
        SINGLETON_NAME = "IAM_DeviceFlow_Client"
    end

    methods (Access = private)
        function obj = DeviceFlowTokenClient(clientId)
            obj@ebrains.iam.OidcTokenClient(clientId);
        end
    end

    methods (Access = protected)
        function fetchToken(obj)
        % fetchToken - Fetch token using device flow

            % openid-connect/auth/device
            endpointUrl = obj.OpenIdConfig.device_authorization_endpoint;
            
            responseDevice = webwrite(endpointUrl, ...
                'client_id', obj.ClientId, ...
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
                    "client_id", obj.ClientId,...
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
    end

    methods (Static)
        function obj = instance(OIDCClientID)
        %instance - Return a singleton instance of the DeviceFlowTokenClient

        %   Note: to achieve persistent singleton instance that survives a 
        %   clear all statement, the singleton instance is stored in the 
        %   graphics root object's UserData property. 
        %   Open question: Are there better ways to do this?

            arguments
                OIDCClientID (1,1) string = "sharebrain"
            end

            authClientObject = [];

            className = string( mfilename('class') );
            singletonName = eval( className + "." + "SINGLETON_NAME" );
            
            rootUserData = get(0, 'UserData');
            if isstruct(rootUserData)
                if isfield(rootUserData, 'SingletonInstances')
                    if isfield(rootUserData.SingletonInstances, singletonName)
                        authClientObject = rootUserData.SingletonInstances.(singletonName);
                    end
                end
            end

            % Create new singleton if we are getting a new client id
            if ~isempty(authClientObject) && isvalid(authClientObject)
                if authClientObject.ClientId ~= OIDCClientID
                    delete(authClientObject)
                    authClientObject = [];
                end
            end

            % - Construct the client if singleton instance is not present
            if isempty(authClientObject) || ~isvalid(authClientObject)
                authClientObject = ebrains.iam.DeviceFlowTokenClient(OIDCClientID);
                
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
