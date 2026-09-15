classdef Scope
    %Scope - OIDC scopes requested when authenticating with EBRAINS
    %   Scope enumerates the scopes that the token clients request from the
    %   EBRAINS identity provider. Every member is requested by default.
    %
    %   Scope members:
    %       openid         - Required by OIDC; grants the basic profile
    %       profile        - More information on the user, if provided
    %       email          - The verified email address of the user
    %       group          - The units and groups the user belongs to
    %       team           - The collabs the user has access to, with roles
    %       roles          - The roles of the user
    %       clb_wiki_read  - Read access to the Collab API
    %       clb_wiki_write - Write access to the Collab API
    %       collab_drive   - Access to the collab drive API
    %       offline_access - Allows refresh tokens for long-term access
    %
    %   Scope properties:
    %       Name - The scope string as sent to the identity provider
    %
    %   See also ebrains.iam.OidcTokenClient

    enumeration
        openid("openid")                 % Required by OIDC; grants username, email and full name
        profile("profile")               % More information on the user, if provided by the user
        email("email")                   % The verified email of the user; add to openid or profile
        group("group")                   % Lets the app identify the units and groups of the user
        team("team")                     % Lets the app identify the collabs and roles of the user
        roles("roles")
        clb_wiki_read("clb.wiki.read")   % Access to GET Collab API
        clb_wiki_write("clb.wiki.write") % Access to DELETE/PUT/POST Collab API
        collab_drive("collab.drive")     % Access to GET/POST/PUT/DELETE drive API
        offline_access("offline_access") % Allows refresh tokens for long-term access without a new login
    end

    properties
        Name  % The scope string as sent to the identity provider
    end

    methods
        function obj = Scope(name)
            obj.Name = name;
        end
    end
end
