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
%   See also: ebrains.iam.OidcTokenClient, ebrains.iam.internal.DeviceLoginDialog

% Details on the Device Authentication Flow
% https://wiki.ebrains.eu/bin/view/Collabs/the-collaboratory/Documentation%20IAM/FAQ/Using%20the%20Device%20Authentication%20Flow/
%
% Developer note:
%   The requests of the flow go through requestDeviceAuthorization and
%   sendTokenRequest, the browser through openVerificationPage, and the
%   progress box through createLoginDialog, so that a test double can
%   drive the flow without a network or a display.

    properties (Constant)
        FLOW_NAME = "Device Flow"
    end

    properties (Constant, Access = private)
        SINGLETON_NAME = "IAM_DeviceFlow_Client"
    end

    methods (Access = protected)
        % Protected rather than private so that a test double can subclass
        % the client; instance() remains the way to get one.
        function obj = DeviceFlowTokenClient(clientId)
            obj@ebrains.iam.OidcTokenClient(clientId);
        end
    end

    methods (Access = protected)
        function fetchToken(obj)
        % fetchToken - Fetch token using OAuth 2.0 Device Authorization Grant

            deviceResponse = obj.requestDeviceAuthorization();

            dialog = obj.createLoginDialog();
            dialogCleanup = onCleanup(@() dialog.close()); % ensure cleanup on any exit

            dialog.showRedirecting()
            dialog.showWaiting()
            
            obj.openVerificationPage(deviceResponse.verification_uri_complete)
            
            pollingInterval = deviceResponse.interval;
            pause(pollingInterval)
            
            deadline = datetime("now") + seconds(double(deviceResponse.expires_in));

            isFinished = false;
            while ~isFinished && datetime("now") < deadline % Poll loop

                response = obj.sendTokenRequest(deviceResponse);
                
                switch response.StatusCode
                    case matlab.net.http.StatusCode.OK
                        obj.handleTokenResponse(response.Body.Data)
                        dialog.showSuccess()
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
                                obj.showErrorDialog('Authentication Failed.', ...
                                    'The device code has expired. Please try connecting again.')
                                error('EBRAINS:DeviceFlow:DeviceCodeExpired', ...
                                    'The device code has expired. Please try connecting again.')
                            
                            case "access_denied"
                                if strcmp(errorData.error_description, 'The end user denied the authorization request')
                                    titleMessage = "Authentication failed";
                                    errorMessage = sprintf(...
                                        ['Make sure the log in to EBRAINS in your web browser and grant access ', ...
                                        'rights to %s before pressing the continue button.'], obj.ClientId);
                                    obj.showErrorDialog(titleMessage, errorMessage)
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
                        obj.showErrorDialog('Authentication Failed', msg);
                        error('EBRAINS:DeviceFlow:UnexpectedHTTPStatus', '%s', msg);
                end
            end

            if ~isFinished
                obj.showErrorDialog('Authentication Timeout', ...
                    'The device authorization session timed out. Please try again.');
                error('EBRAINS:DeviceFlow:Timeout', 'Polling exceeded device authorization window.');
            end
        end

        function deviceResponse = requestDeviceAuthorization(obj)
        % requestDeviceAuthorization - Start the device flow and get the codes to poll with
            endpointUrl = obj.getOpenIdConfig().device_authorization_endpoint; % openid-connect/auth/device
            deviceResponse = webwrite(endpointUrl, ...
                'client_id', obj.ClientId, ...
                'scope', strjoin( obj.Scope, " ") );
        end

        function openVerificationPage(~, url)
        % openVerificationPage - Open the page where the user grants access
            web(url)
        end

        function dialog = createLoginDialog(~)
        % createLoginDialog - The box that shows the progress of the login
            dialog = ebrains.iam.internal.DeviceLoginDialog();
        end

        function response = sendTokenRequest(obj, deviceResponse)
        % sendTokenRequest - Poll the token endpoint once with the device code
            try
                endpointURI = matlab.net.URI(obj.getOpenIdConfig().token_endpoint);
                
                % Define request body (form data)
                formData = struct( ...
                    'grant_type', 'urn:ietf:params:oauth:grant-type:device_code', ...
                    'client_id', obj.ClientId, ...
                    'device_code', deviceResponse.device_code);
        
                % Hold the content provider in a named variable. FormProvider is
                % a handle object; as an unnamed temporary it is released at the
                % end of the construction statement (R2025b), leaving
                % RequestMessage.Body pointing at a deleted object and causing
                % send() to fail with "Invalid or deleted object".
                bodyProvider = matlab.net.http.io.FormProvider(formData);

                % Create POST request
                req = matlab.net.http.RequestMessage('POST', ...
                    [matlab.net.http.HeaderField('Content-Type', 'application/x-www-form-urlencoded')], ...
                    bodyProvider);
                
                % Send request
                response = req.send(endpointURI);
            catch MECause
                ME = MException('EBRAINS:DeviceFlow:AuthenticationFailed', ...
                    'Failed to send token request.');
                ME = ME.addCause(MECause);
                throw(ME)
            end
        end
    end

    methods (Access = private)
        function handleTokenResponse(obj, tokenResponse)
            obj.AccessToken_ = tokenResponse.access_token;
            obj.RefreshToken = tokenResponse.refresh_token;
            
            obj.AccessTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.expires_in);
    
            obj.RefreshTokenExpiresAt = ...
                datetime("now") + seconds(tokenResponse.refresh_expires_in);
        end

        function handleUnspecifiedBadRequestError(obj, errorData)
            titleMessage = errorData.error;
            errorMessage = errorData.error_description;
            obj.showErrorDialog(titleMessage, errorMessage)
            error('EBRAINS:DeviceFlow:BadRequest', '%s', errorMessage)
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
                OIDCClientID (1,1) string = missing
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

            if isempty(authClientObject) && ismissing(OIDCClientID)
                % Create token client using this toolbox' default OIDC Client
                OIDCClientID = ebrains.common.constant.OIDCClientID;
            end

            % Create new singleton if we are getting a new client id
            if ~isempty(authClientObject) && isvalid(authClientObject)
                if ~ismissing(OIDCClientID)
                    if authClientObject.ClientId ~= OIDCClientID
                        delete(authClientObject)
                        authClientObject = [];
                    end
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

