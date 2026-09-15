classdef (Abstract) OidcTokenClient < handle & matlab.mixin.CustomDisplay
%OidcTokenClient - Base class for the EBRAINS OIDC token clients
%   OidcTokenClient holds an access token for the EBRAINS identity
%   provider and refreshes it when it expires. It cannot be created
%   directly. Use the INSTANCE method of a subclass, each of which
%   implements one authentication flow, or call AUTHENTICATE and
%   getTokenManager from the ebrains namespace.
%
%   A token found in the EBRAINS_TOKEN secret or environment variable
%   is loaded when a client is created.
%
%   OidcTokenClient functions:
%       authenticate         - Fetch a token, or refresh the active one
%       hasActiveToken       - Whether the access token is still valid
%       canAuthenticate      - Whether the client has held a token before
%       getFlowName          - Name of the authentication flow
%       getAuthHeaderField   - Authorization header for matlab.net.http
%       getWebOptions        - weboptions carrying the Authorization header
%       copyTokenToClipboard - Copy the access token to the clipboard
%       reset                - Delete a stored singleton client
%       resetAll             - Delete every stored singleton client
%
%   OidcTokenClient properties:
%       ClientId    - OIDC client id the client authenticates as
%       Scope       - Scopes requested with the token
%       AccessToken - The access token, fetched or refreshed on demand
%       ExpiresIn   - Time left until the access token expires
%
%   See also ebrains.authenticate, ebrains.getTokenManager,
%   DeviceFlowTokenClient, ClientCredentialsFlowTokenClient,
%   ebrains.iam.enum.Scope

% Developer note:
%   Every request to the identity provider goes through one of the
%   protected request methods (requestOpenIdConfiguration, requestToken),
%   and the only dialog of this class through showErrorDialog, so that a
%   test double can answer them without a network or a display.

    properties (Abstract, Constant)
        FLOW_NAME (1,1) string  % Display name of the authentication flow
    end

    properties (SetAccess = private)
        ClientId (1,1) string  % OIDC client id the client authenticates as
    end

    properties
        Scope = [ enumeration('ebrains.iam.enum.Scope').Name ]  % Scopes requested with the token
    end

    properties (Dependent, SetAccess = private)
        AccessToken  % The access token, fetched or refreshed on demand
        ExpiresIn    % Time left until the access token expires
    end

    properties (Access = protected)
        OpenIdConfig
        AccessToken_ (1,1) string = missing
        RefreshToken (1,1) string
        AccessTokenExpiresAt
        RefreshTokenExpiresAt
    end

    properties (Access = private)
        LastWarnTime uint64 = 0
    end

    properties (Constant, Access = protected)
        IAM_BASE_URL = ...
            "https://iam.ebrains.eu/auth/realms/hbp/"

        WELL_KNOWN_CONFIGURATION_ENDPOINT = ...
            ".well-known/openid-configuration"
    end

    methods (Abstract, Access = protected)
        fetchToken(obj)
        %fetchToken - Fetch a token with the flow of the subclass
    end

    methods
        function flowName = getFlowName(obj)
        %getFlowName - Name of the authentication flow
        %   flowName = getFlowName(OBJ) returns the display name of the flow
        %   the client implements, such as "Device Flow".

            flowName = obj.FLOW_NAME;
        end

        function authenticate(obj)
        %AUTHENTICATE - Fetch a token, or refresh the active one
        %   AUTHENTICATE(OBJ) runs the authentication flow of the client
        %   when it has no active token, and refreshes the token otherwise.

            if ~obj.hasActiveToken()
                obj.fetchToken()
            else
                obj.refreshToken()
            end
        end
    end

    methods (Access = protected)
        function obj = OidcTokenClient(clientId)
            % The OpenID configuration is fetched on the first token request
            % rather than here, so that creating a client needs no network.
            obj.tryLoadTokenFromEnvironment()
            obj.ClientId = clientId;
        end

        function tryLoadTokenFromEnvironment(obj)
        %tryLoadTokenFromEnvironment - Load a token from secrets or environment

            % Try to get from secrets
            if exist("isSecret", "file")
                try
                    if isSecret('EBRAINS_TOKEN')
                        obj.AccessToken_ = getSecret('EBRAINS_TOKEN');
                        obj.decodeTokenExpiryTime()
                        return
                    end
                catch
                    % Try to get via env instead
                end
            end

            % Try to get from env
            if isenv('EBRAINS_TOKEN')
                obj.AccessToken_ = getenv('EBRAINS_TOKEN');
                obj.decodeTokenExpiryTime()
            end
        end

        function config = getOpenIdConfig(obj)
        %getOpenIdConfig - The OpenID configuration, fetched once on first use
            if isempty(obj.OpenIdConfig)
                obj.OpenIdConfig = obj.requestOpenIdConfiguration();
            end
            config = obj.OpenIdConfig;
        end

        function config = requestOpenIdConfiguration(obj)
        %requestOpenIdConfiguration - Fetch the OpenID configuration
            config = webread(obj.IAM_BASE_URL + obj.WELL_KNOWN_CONFIGURATION_ENDPOINT);
        end

        function tokenResponse = requestToken(obj, formFields)
        %requestToken - Post form fields to the token endpoint

            arguments
                obj (1,1) ebrains.iam.OidcTokenClient
                formFields (1,:) cell
            end
            tokenResponse = webwrite(obj.getOpenIdConfig().token_endpoint, formFields{:});
        end

        function showErrorDialog(~, titleMessage, errorMessage)
        %showErrorDialog - Show an error in a dialog box
            errordlg(errorMessage, titleMessage);
        end

        function decodeTokenExpiryTime(obj)
        %decodeTokenExpiryTime - Read the expiry time out of the access token

            obj.AccessTokenExpiresAt = ...
                ebrains.internal.get_token_expiration(obj.AccessToken_);
            obj.AccessTokenExpiresAt.TimeZone = '';
        end

        function refreshToken(obj)
        %refreshToken - Refresh the access token using the refresh token

            % Check if refresh token exists
            if obj.RefreshToken == "" || ismissing(obj.RefreshToken)
                obj.fetchToken()
            end

            try
                % Request a new access token using the refresh token
                tokenResponse = obj.requestToken({ ...
                    "grant_type", "refresh_token", ...
                    "client_id", obj.ClientId, ...
                    "refresh_token", obj.RefreshToken ...
                    });

                % Update object properties with new token values
                obj.AccessToken_ = tokenResponse.access_token;
                obj.RefreshToken = tokenResponse.refresh_token;

                obj.AccessTokenExpiresAt = ...
                    datetime("now") + seconds(tokenResponse.expires_in);

                obj.RefreshTokenExpiresAt = ...
                    datetime("now") + seconds(tokenResponse.refresh_expires_in);

                % Log success
                disp("Access token successfully refreshed.");

            catch ME
                titleMessage = "Token Refresh Failed";
                switch ME.identifier
                    case 'MATLAB:webservices:HTTP400StatusCodeError'
                        % Re-authenticate if refresh token is invalid
                        obj.fetchToken()
                    otherwise
                        obj.showErrorDialog(titleMessage, ME.message);
                        throwAsCaller(ME);
                end
            end
        end
    end

    methods (Access = protected) % CustomDisplay override
        function groups = getPropertyGroups(obj)
        %getPropertyGroups - Display the properties with the token masked

            propNames = properties(obj);

            s = struct();
            for i = 1:numel(propNames)
                if strcmp(propNames{i}, 'AccessToken')
                    s.(propNames{i}) = categorical({'********'});
                else
                    s.(propNames{i}) = obj.(propNames{i});
                end
            end

            groups = matlab.mixin.util.PropertyGroup(s);
        end
    end

    methods
        function opts = getWebOptions(obj, opts)
        %getWebOptions - weboptions carrying the Authorization header
        %   OPTS = getWebOptions(OBJ) returns a weboptions object whose header
        %   fields carry the bearer token of the client, for use with webread
        %   and webwrite.
        %
        %   OPTS = getWebOptions(OBJ,OPTS) adds the header to the given
        %   weboptions object instead of a new one.

            arguments
                obj
                opts weboptions = weboptions
            end

            opts.HeaderFields = [ opts.HeaderFields, ...
                "Authorization", sprintf("Bearer %s", obj.AccessToken)];
        end

        function authField = getAuthHeaderField(obj)
        %getAuthHeaderField - Authorization header for matlab.net.http
        %   authField = getAuthHeaderField(OBJ) returns an AuthorizationField
        %   carrying the bearer token of the client, for use in a
        %   matlab.net.http.RequestMessage.

            authField = matlab.net.http.field.AuthorizationField(...
                'Authorization', sprintf('Bearer %s', obj.AccessToken));
        end

        function tf = hasActiveToken(obj)
        %hasActiveToken - Whether the access token is still valid
        %   TF = hasActiveToken(OBJ) is true when the client holds an access
        %   token that has not expired. A warning is issued when the token
        %   has expired or expires within the hour.

            tf = false;

            if ~ismissing(obj.AccessToken_) && ~ismissing(obj.ExpiresIn)
                tf = obj.ExpiresIn > seconds(0);
                warnState = warning('off', 'backtrace');
                warningCleanup = onCleanup(@() warning(warnState));
                if obj.ExpiresIn < 0
                    warning("EBRAINS:IAM:TokenExpired", ...
                        "EBRAINS Access token expired %d minutes ago.", abs(round(seconds(obj.ExpiresIn)/60)))
                elseif obj.ExpiresIn < seconds(3600)
                    elapsed = toc(obj.LastWarnTime);
                    if elapsed > 60*10 % 10 minutes
                        warning("EBRAINS:IAM:TokenExpiresSoon", ...
                            "EBRAINS Access token expires in %d minutes", round(seconds(obj.ExpiresIn)/60))
                        obj.LastWarnTime = tic;
                    end
                end
            end
        end

        function tf = canAuthenticate(obj)
        %canAuthenticate - Whether the client has held a token before
        %   TF = canAuthenticate(OBJ) is true when the client has an access
        %   token, expired or not. A client that authenticated once is
        %   assumed to be able to do so again.

            tf = ~ismissing(obj.AccessToken_);
        end

        function copyTokenToClipboard(obj)
        %copyTokenToClipboard - Copy the access token to the clipboard
        %   copyTokenToClipboard(OBJ) copies the current access token to the
        %   system clipboard without refreshing it.

            clipboard("copy", obj.AccessToken_)
        end
    end

    methods
        function remainingTime = get.ExpiresIn(obj)
            if isempty(obj.AccessTokenExpiresAt)
                remainingTime = duration(missing);
            else
                currentTime = datetime("now");
                remainingTime = obj.AccessTokenExpiresAt - currentTime;
            end
        end

        function accessToken = get.AccessToken(obj)
            if ismissing(obj.AccessToken_)
                obj.fetchToken()
            end
            if ~obj.hasActiveToken()
                obj.refreshToken()
            end
            accessToken = obj.AccessToken_;
        end
    end

    methods (Static)
        function reset(singletonName)
        %RESET - Delete a stored singleton client
        %   ebrains.iam.OidcTokenClient.reset(singletonName) deletes the token
        %   client stored under singletonName in the UserData of the graphics
        %   root and removes the entry, so that the next INSTANCE call creates
        %   a new client.

            arguments
                singletonName (1,1) string
            end
            rootUserData = get(0, 'UserData');
            if isstruct(rootUserData)
                if isfield(rootUserData, 'SingletonInstances')
                    if isfield(rootUserData.SingletonInstances, singletonName)
                        authClientObject = rootUserData.SingletonInstances.(singletonName);
                        delete(authClientObject)
                        rootUserData.SingletonInstances = ...
                            rmfield(rootUserData.SingletonInstances, singletonName);
                        set(0, 'UserData', rootUserData)
                    end
                end
            end
        end

        function resetAll()
        %resetAll - Delete every stored singleton client
        %   ebrains.iam.OidcTokenClient.resetAll() deletes the stored device
        %   flow and client credentials clients, so that the next INSTANCE
        %   call of either creates a new one.

            ebrains.iam.OidcTokenClient.reset("IAM_DeviceFlow_Client")
            ebrains.iam.OidcTokenClient.reset("IAM_ClientCredentials_Client")
        end
    end
end
