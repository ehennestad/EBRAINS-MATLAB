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
        % fetchToken - Fetch token using OAuth 2.0 Device Authorization Grant

            endpointUrl = obj.OpenIdConfig.device_authorization_endpoint; % openid-connect/auth/device
            
            deviceResponse = webwrite(endpointUrl, ...
                'client_id', obj.ClientId, ...
                'scope', strjoin( obj.Scope, " ") );

            message = "Redirecting to web browser to authenticate...";
            f = msgbox(message, "Authenticating...");
            figureCleanup = onCleanup(@() safeDeleteFigure(f)); % ensure cleanup on any exit

            reformatMessageBoxBeforeRedirecting(f)
            setMessage(f, "Redirecting to web browser to authenticate...");
            pause(1)
            setMessage(f, "Waiting for device login...");
            
            % Open browser
            web(deviceResponse.verification_uri_complete)
            
            pollingInterval = deviceResponse.interval;
            pause(pollingInterval)
            
            isFinished = false;
            while ~isFinished % Poll loop

                response = obj.sendTokenRequest(deviceResponse);
                
                switch response.StatusCode
                    case matlab.net.http.StatusCode.OK
                        obj.handleTokenResponse(response.Body.Data)
                        showSuccess(f)
                        isFinished = true;

                    case matlab.net.http.StatusCode.BadRequest
                        errorData = response.Body.Data;

                        switch string(errorData.error)
                            case "authorization_pending"
                                pause(pollingInterval)

                            case "slow_down"
                                pollingInterval = pollingInterval + deviceResponse.interval;
                                pause(pollingInterval)

                            case "expired_token"
                                delete(f)
                                errordlg('The device code has expired. Please try connecting again.', 'Authentication Failed.')
                                error('EBRAINS:DeviceFlow:DeviceCodeExpired', ...
                                    'The device code has expired. Please try connecting again.')
                            
                            case "access_denied"
                                if strcmp(errorData.error_description, 'The end user denied the authorization request')
                                    titleMessage = "Authentication failed";
                                    errorMessage = sprintf(...
                                        ['Make sure the log in to EBRAINS in your web browser and grant access ', ...
                                        'rights to %s before pressing the continue button.'], obj.ClientId);
                                    errordlg(errorMessage, titleMessage)
                                    error('EBRAINS:DeviceFlow:AccessDenied', errorMessage) %#ok<SPERR>
                                else
                                    obj.handleUnspecifiedBadRequestError(errorData)
                                end
                            otherwise
                                obj.handleUnspecifiedBadRequestError(errorData)
                        end
                    otherwise
                        msg = sprintf('Unexpected HTTP status: %s', string(response.StatusCode));
                        if ~isempty(response.Body) && ~isempty(response.Body.Data)
                            try
                                serverMsg = jsonencode(response.Body.Data);
                                msg = msg + " | " + serverMsg;
                            catch
                                % ignore JSON errors
                            end
                        end
                        errordlg(msg, 'Authentication Failed');
                        error('EBRAINS:DeviceFlow:UnexpectedHTTPStatus', '%s', msg);
                end
            end
        end
    end

    methods (Access = private)
        function response = sendTokenRequest(obj, deviceResponse)
            try
                endpointURI = matlab.net.URI(obj.OpenIdConfig.token_endpoint);
                
                % Define request body (form data)
                formData = struct( ...
                    'grant_type', 'urn:ietf:params:oauth:grant-type:device_code', ...
                    'client_id', obj.ClientId, ...
                    'device_code', deviceResponse.device_code);
        
                % Create POST request
                req = matlab.net.http.RequestMessage('POST', ...
                    [matlab.net.http.HeaderField('Content-Type', 'application/x-www-form-urlencoded')], ...
                    matlab.net.http.io.FormProvider(formData));
                
                % Send request
                response = req.send(endpointURI);
            catch MECause
                ME = MException('EBRAINS:DeviceFlow:AuthenticationFailed', ...
                    'Failed to send token request.');
                ME = ME.addCause(MECause);
                throw(ME)
            end
        end
        
        function handleTokenResponse(obj, tokenResponse)
            obj.AccessToken_ = tokenResponse.access_token;
            obj.RefreshToken = tokenResponse.refresh_token;
            
            obj.AccessTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.expires_in);
    
            obj.RefreshTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.refresh_expires_in);
        end

        function handleUnspecifiedBadRequestError(~, errorData)
            titleMessage = errorData.error;
            errorMessage = errorData.error_description;
            errordlg(errorMessage, titleMessage)
            error(errorMessage)
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
                OIDCClientID (1,1) string = ebrains.common.constant.OIDCClientID
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
            
        function reset()
            className = string( mfilename('class') );
            singletonName = eval( className + "." + "SINGLETON_NAME" );
            ebrains.iam.OidcTokenClient.reset(singletonName)
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

function setMessage(hFigure, message)
    hFigure.Children(2).Children(1).String = message;
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

function safeDeleteFigure(f)
    if isvalid(f)
        try delete(f); catch, end
    end
end
