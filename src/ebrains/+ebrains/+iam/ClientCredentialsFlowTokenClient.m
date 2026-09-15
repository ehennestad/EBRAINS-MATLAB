classdef ClientCredentialsFlowTokenClient < ebrains.iam.OidcTokenClient
%ClientCredentialsFlowTokenClient - Token client for service logins
%   CLIENT = ebrains.iam.ClientCredentialsFlowTokenClient.instance(clientId,clientSecret)
%   returns the shared client for the OAuth 2.0 Client Credentials
%   Grant, creating it on first use. The flow authenticates a service
%   with its client id and secret and needs no user interaction.
%
%   The shared client is stored in the UserData of the graphics root so
%   that it survives a clear all. Use RESET to remove it. The remaining
%   methods and properties are inherited from OidcTokenClient.
%
%   ClientCredentialsFlowTokenClient functions:
%       instance - The shared client, created on first use
%       reset    - Delete the shared client
%
%   See also OidcTokenClient, DeviceFlowTokenClient,
%   ebrains.authenticate, ebrains.getTokenManager

    properties (Constant)
        FLOW_NAME = "Client Credentials Flow"  % Display name of the authentication flow
    end

    properties (Access = private)
        ClientSecret (1,1) string
    end

    properties (Constant, Access = private)
        SINGLETON_NAME = "IAM_ClientCredentials_Client"
    end

    methods (Access = protected)
        % Protected rather than private so that a test double can subclass
        % the client; instance() remains the way to get one.
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
        %fetchToken - Fetch a token with the OAuth 2.0 Client Credentials Grant

            obj.assertHasCredentials()

            try
                % Request an access token using client credentials
                tokenResponse = obj.requestToken({ ...
                    "grant_type", "client_credentials", ...
                    "client_id", obj.ClientId, ...
                    "client_secret", obj.ClientSecret ...
                    });

                obj.AccessToken_ = tokenResponse.access_token;

                obj.AccessTokenExpiresAt = ...
                    datetime("now") + seconds(tokenResponse.expires_in);

                % Note: Client credentials flow typically does not provide a refresh token
                obj.RefreshToken = missing;
                obj.RefreshTokenExpiresAt = [];

                disp("Access token successfully retrieved using client credentials.");

            catch ME
                switch ME.identifier
                    case 'MATLAB:webservices:HTTP400StatusCodeError'
                        errorMessage = "Invalid client credentials. Please verify your client ID and secret.";
                        disp(errorMessage)
                        throwAsCaller(ME)
                    case 'MATLAB:webservices:HTTP401StatusCodeError'
                        errorMessage = "Unauthorized. The client credentials are not valid.";
                        disp(errorMessage)
                        throwAsCaller(ME)
                    otherwise
                        disp(ME.message)
                        throwAsCaller(ME)
                end
            end
        end

        function refreshToken(obj)
        %refreshToken - Fetch a new token, as this flow has no refresh token

            obj.fetchToken();
        end

        function assertHasCredentials(obj)
        %assertHasCredentials - Raise an error when there is nothing to authenticate with
        %   The client is also the one that carries a token given through
        %   EBRAINS_TOKEN, and that client has no credentials of its own.
        %   Requesting a token with the empty ones is refused by the
        %   identity provider as invalid client credentials, which tells a
        %   caller whose token simply expired to go and check credentials
        %   it never gave.

            if strlength(obj.ClientId) > 0 && strlength(obj.ClientSecret) > 0
                return
            end

            if ismissing(obj.AccessToken_)
                error('EBRAINS:IAM:MissingClientCredentials', ...
                    ['The client credentials flow needs a client id and a client ', ...
                    'secret. Call ebrains.authenticate with ', ...
                    'OAuthFlow="ClientCredentialsFlow" and give OIDCClientID ', ...
                    'and OIDCClientSecret.'])
            else
                error('EBRAINS:IAM:MissingClientCredentials', ...
                    ['The EBRAINS access token has expired, and there is no ', ...
                    'client id and client secret to fetch a new one with. An ', ...
                    'access token taken from the EBRAINS_TOKEN environment ', ...
                    'variable cannot be renewed by this toolbox: set ', ...
                    'EBRAINS_TOKEN to a valid token, or call ', ...
                    'ebrains.authenticate to log in.'])
            end
        end
    end

    methods (Static)
        function obj = instance(clientId, clientSecret)
        %INSTANCE - The shared client, created on first use
        %   CLIENT = ebrains.iam.ClientCredentialsFlowTokenClient.instance(clientId,clientSecret)
        %   returns the stored client for the given credentials, creating one
        %   when none is stored. A stored client with different credentials
        %   is replaced, with a warning.
        %
        %   CLIENT = ebrains.iam.ClientCredentialsFlowTokenClient.instance()
        %   returns the stored client without checking its credentials, and
        %   creates a client with empty credentials when none is stored.

        %   Note: to achieve persistent singleton instance that survives a
        %   clear all statement, the singleton instance is stored in the
        %   graphics root object's UserData property.
        %   Open question: Are there better ways to do this?

            arguments
                clientId (1,1) string = ""
                clientSecret (1,1) string = ""
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
                            credentialsDiffer = ...
                                authClientObject.ClientId ~= clientId || ...
                                authClientObject.ClientSecret ~= clientSecret;

                            if clientId ~= "" && credentialsDiffer
                                % A stored client without credentials is the
                                % one getTokenManager creates to look for a
                                % token, which every API call does. Giving it
                                % credentials for the first time is not a
                                % change of credentials, and saying so would
                                % warn the caller about their own first login.
                                if strlength(authClientObject.ClientId) > 0
                                    warning('EBRAINS:IAM:CredentialsChanged', ...
                                        'Different credentials provided. Creating new instance.');
                                end
                                authClientObject = [];
                            end
                        else
                            authClientObject = [];
                        end
                    end
                end
            end

            % - Construct the client if singleton instance is not present
            if isempty(authClientObject) || ~isvalid(authClientObject)
                authClientObject = ebrains.iam.ClientCredentialsFlowTokenClient(...
                    clientId, clientSecret);

                rootUserData.SingletonInstances.(singletonName) = authClientObject;
                set(0, 'UserData', rootUserData)
            end

            % - Return the instance
            obj = authClientObject;
        end

        function reset()
        %RESET - Delete the shared client
        %   ebrains.iam.ClientCredentialsFlowTokenClient.reset() deletes the
        %   stored client so that the next INSTANCE call creates a new one.

            className = string( mfilename('class') );
            singletonName = eval( className + "." + "SINGLETON_NAME" );
            ebrains.iam.OidcTokenClient.reset(singletonName)
        end
    end
end
