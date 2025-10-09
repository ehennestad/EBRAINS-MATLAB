classdef ClientCredentialsFlowTokenClient < ebrains.iam.OidcTokenClient
% ClientCredentialsFlowTokenClient - Client for OIDC Client Credentials Flow
%
%   This client implements the OAuth 2.0 Client Credentials Grant flow
%   for authenticating with EBRAINS IAM. This flow is typically used for
%   service-to-service authentication where no user interaction is required.
%
%   USAGE:
%       authClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance(...
%           clientId, clientSecret) creates a client or retrieves an 
%           existing (persistent) client
%
%       authClient.fetchToken() retrieves an access token using the
%           client credentials
%
%   See also: ebrains.iam.OidcTokenClient

    properties (Constant)
        FLOW_NAME = "Client Credentials Flow"
    end

    properties (Access = private)
        ClientSecret (1,1) string
    end

    properties (Constant, Access = private)
        SINGLETON_NAME = "IAM_ClientCredentials_Client"
    end
    
    methods (Access = private)
        function obj = ClientCredentialsFlowTokenClient(clientId, clientSecret)
            arguments
                clientId (1,1) string
                clientSecret (1,1) string
            end
            
            obj@ebrains.iam.OidcTokenClient(clientId);
            obj.ClientSecret = clientSecret;
        end
    end

    methods (Access = protected)
        function fetchToken(obj)
        % fetchToken - Fetch token using client credentials flow

            try
                % Request an access token using client credentials
                tokenResponse = webwrite(obj.OpenIdConfig.token_endpoint, ...
                    "grant_type", "client_credentials", ...
                    "client_id", obj.ClientId, ...
                    "client_secret", obj.ClientSecret, ...
                    "scope", strjoin(obj.Scope, " ") ...
                );
                
                obj.AccessToken_ = tokenResponse.access_token;
                
                obj.AccessTokenExpiresAt = ...
                    datetime("now") + seconds(tokenResponse.expires_in);
                
                % Note: Client credentials flow typically does not provide a refresh token
                obj.RefreshToken = missing;
                obj.RefreshTokenExpiresAt = [];
                
                disp("Access token successfully retrieved using client credentials.");
                
            catch ME
                titleMessage = "Authentication failed";
                
                switch ME.identifier
                    case 'MATLAB:webservices:HTTP400StatusCodeError'
                        errorMessage = "Invalid client credentials. Please verify your client ID and secret.";
                        errordlg(errorMessage, titleMessage)
                        throwAsCaller(ME) 
                    case 'MATLAB:webservices:HTTP401StatusCodeError'
                        errorMessage = "Unauthorized. The client credentials are not valid.";
                        errordlg(errorMessage, titleMessage)
                        throwAsCaller(ME)
                    otherwise
                        errordlg(ME.message, titleMessage)
                        throwAsCaller(ME) 
                end
            end
        end
    end

    methods
        function refreshToken(obj)
            % refreshToken - For client credentials flow, just fetch a new token
            %
            % Client credentials flow typically doesn't provide refresh tokens,
            % so we simply fetch a new token instead.
            
            obj.fetchToken();
        end
    end

    methods (Static)
        function obj = instance(clientId, clientSecret)
        %instance - Return a singleton instance of the ClientCredentialsFlowTokenClient
        %
        %   INPUTS:
        %       clientId - The OAuth client ID
        %       clientSecret - The OAuth client secret

        %   Note: to achieve persistent singleton instance that survives a 
        %   clear all statement, the singleton instance is stored in the 
        %   graphics root object's UserData property. 
        %   Open question: Are there better ways to do this?

            arguments
                clientId (1,1) string
                clientSecret (1,1) string
            end

            authClientObject = [];

            className = string( mfilename('class') );
            singletonName = eval( className + "." + "SINGLETON_NAME" );
            
            rootUserData = get(0, 'UserData');
            if isstruct(rootUserData)
                if isfield(rootUserData, 'SingletonInstances')
                    if isfield(rootUserData.SingletonInstances, singletonName)
                        authClientObject = rootUserData.SingletonInstances.(singletonName);
                        
                        % Verify credentials match
                        if isvalid(authClientObject)
                            if authClientObject.ClientId ~= clientId || ...
                               authClientObject.ClientSecret ~= clientSecret
                                warning('Different credentials provided. Creating new instance.');
                                authClientObject = [];
                            end
                        else
                            authClientObject = [];
                        end
                    end
                end
            end

            % - Construct the client if singleton instance is not present
            if isempty(authClientObject)
                authClientObject = ebrains.iam.ClientCredentialsFlowTokenClient(...
                    clientId, clientSecret);
                
                rootUserData.SingletonInstances.(singletonName) = authClientObject;
                set(0, 'UserData', rootUserData)
            end
        
            % - Return the instance
            obj = authClientObject;
        end
    end
end
