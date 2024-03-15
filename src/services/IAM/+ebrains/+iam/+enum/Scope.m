classdef Scope
    enumeration
        openid("openid")                 % This scope is required because we use the OIDC protocol. It will give your app access to the user's basic information such as username, email and full name.
        profile("profile")               % More information on user if provided by the user
        email("email")                   % The verified email of the user, should be added in addition to openid and/or profile to get the email.
        group("group")                   % If you request this scope, the future access token generated will authorize your app to identify which units and groups the user belongs to.
        team("team")                     % This scope is like the group scope lets your app identify the permissions of the user, but by identifying what collabs the user has access to and with what roles.
        roles("roles")
        clb_wiki_read("clb.wiki.read")   % Access to GET Collab API
        clb_wiki_write("clb.wiki.write") % Access to DELETE/PUT/POST Collab API
        collab_drive("collab.drive")     % Access to GET/POST/PUT/DELETE drive API
        offline_access("offline_access") % Allows the app to obtain refresh tokens for long-term access without requiring the user to authenticate again.
    end

    properties
        Name
    end
    
    methods
        function obj = Scope(name)
            obj.Name = name;
        end
    end
end
