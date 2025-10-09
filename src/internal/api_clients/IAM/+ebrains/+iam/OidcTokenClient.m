classdef (Abstract) OidcTokenClient < handle
% OidcTokenClient - Abstract base class for OIDC token authentication
%
%   This abstract class provides common functionality for OIDC token
%   authentication flows. Subclasses must implement specific authentication
%   flows (e.g., device flow, client credentials flow).
%
%   USAGE:
%       Subclasses should implement:
%       - fetchToken() - Flow-specific token retrieval

    properties (Abstract, Constant)
        FLOW_NAME (1,1) string
    end

    properties (SetAccess = private)
        ClientId (1,1) string
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
        % fetchToken - Fetch token using the specific authentication flow
        %   Subclasses must implement this method to perform the 
        %   flow-specific token retrieval.
    end

    methods
        function flowName = getFlowName(obj)
        % getFlowName - Return the name of the authentication flow
        %   Returns a string describing the authentication flow type
            flowName = obj.FLOW_NAME;
        end
    end
    
    methods (Access = protected)
        function obj = OidcTokenClient(clientId)
            obj.initOidc()
            obj.tryLoadTokenFromEnvironment()
            obj.ClientId = clientId;
        end

        function tryLoadTokenFromEnvironment(obj)
        % tryLoadTokenFromEnvironment - Try to load token from secrets or environment
            
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

        function refreshToken(obj)
            % refreshToken - Refresh the access token using the refresh token
        
            % Check if refresh token exists
            if obj.RefreshToken == "" || ismissing(obj.RefreshToken)
                obj.fetchToken()
            end
        
            try
                % Request a new access token using the refresh token
                tokenResponse = webwrite(obj.OpenIdConfig.token_endpoint, ...
                    "grant_type", "refresh_token", ...
                    "client_id", obj.ClientId, ...
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
                        % Re-authenticate if refresh token is invalid
                        obj.fetchToken()
                    otherwise
                        errordlg(ME.message, titleMessage);
                        throwAsCaller(ME);
                end
            end
        end

        function tf = hasActiveToken(obj)
            tf = false;

            if ~ismissing(obj.AccessToken_) && ~ismissing(obj.ExpiresIn)
                tf = obj.ExpiresIn > seconds(0);
                warnState = warning('off', 'backtrace');
                warningCleanup = onCleanup(@() warning(warnState));
                if obj.ExpiresIn < 0
                    warning("EBRAINS Access token expired %d minutes ago.", abs(round(seconds(obj.ExpiresIn)/60)))
                elseif obj.ExpiresIn < seconds(3600)
                    elapsed = toc(obj.LastWarnTime);
                    if elapsed > 60*10 % 10 minutes
                        warning("EBRAINS Access token expires in %d minutes", round(seconds(obj.ExpiresIn)/60))
                        obj.LastWarnTime = tic;
                    end
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
end
