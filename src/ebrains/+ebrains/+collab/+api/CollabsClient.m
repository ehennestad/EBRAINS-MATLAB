classdef CollabsClient < ebrains.common.internal.HttpClient
% CollabsClient - Client for the collab endpoints of the EBRAINS Collaboratory
%
%   Each method mirrors one endpoint under /collabs of the Collaboratory
%   REST API.
%
%   The requests go to the Collaboratory server of the Environment
%   preference: wiki.ebrains.eu for "prod" (the default) and
%   wiki-int.ebrains.eu for "int". ebrains.useEnvironment sets the
%   preference for the current MATLAB session.
%
%   Example:
%       client = ebrains.collab.api.CollabsClient();
%       collabs = client.searchCollabs(search="dataset", limit=50);
%       client.createCollab("my-collab", "My collab", public=false)
%       client.addTeamUser("my-collab", "editor", "username")
%
%   See also ebrains.useEnvironment,
%   ebrains.common.constant.CollabApiBaseUrl

    properties (Constant, Access = protected)
        ErrorIdPrefix = "EBRAINS:Collab"
    end

    methods
        function collabs = searchCollabs(obj, optionalParams)
        % searchCollabs - List the collabs that match the search criteria
        %
        %   collabs = client.searchCollabs() returns a struct array with
        %   one element per collab.
        %
        %   collabs = client.searchCollabs(Name=Value) passes the query
        %   parameters of the endpoint. Some of them exclude the others,
        %   as documented by the API:
        %       search      - Keyword searched in titles and descriptions
        %       driveId     - Drive id of a single collab
        %       collabTitle - Title of a single collab
        %       limit       - Number of results per page
        %       offset      - Number of results to skip
        %       orderField  - "title", "createDate" or "mostLiked"
        %       order       - "asc" or "desc"
        %       favorite    - Only collabs the user marked as favorite
        %       memberOnly  - Only collabs the user is a member of
        %       roles       - "viewer", "editor" or "administrator"
        %       visibility  - "public" or "private"

            arguments
                obj (1,1) ebrains.collab.api.CollabsClient
                optionalParams.search (1,1) string
                optionalParams.driveId (1,1) string
                optionalParams.collabTitle (1,1) string
                optionalParams.limit (1,1) int32
                optionalParams.offset (1,1) int32
                optionalParams.orderField (1,1) string ...
                    {mustBeMember(optionalParams.orderField, ["title", "createDate", "mostLiked"])}
                optionalParams.order (1,1) string ...
                    {mustBeMember(optionalParams.order, ["asc", "desc"])}
                optionalParams.favorite (1,1) logical
                optionalParams.memberOnly (1,1) logical
                optionalParams.roles (1,1) string ...
                    {mustBeMember(optionalParams.roles, ["viewer", "editor", "administrator"])}
                optionalParams.visibility (1,1) string ...
                    {mustBeMember(optionalParams.visibility, ["public", "private"])}
            end

            request = obj.initializeRequestMessage("GET");
            apiUri = ebrains.common.internal.buildApiUri(...
                ebrains.common.constant.CollabApiBaseUrl(), "collabs", struct.empty, optionalParams);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode == "OK"
                collabs = response.Body.Data;
            else
                obj.throwError("searchCollabs", response)
            end
        end

        function createCollab(obj, name, title, collabOptions)
        % createCollab - Create a collab
        %
        %   client.createCollab(name, title) creates a collab with the
        %   given name and title. The name is the id of the collab in its
        %   URL and in the paths of the API. The request fails with 409
        %   (Conflict) when a collab with that name exists.
        %
        %   client.createCollab(name, title, Name=Value) also sets fields
        %   of the request body. A field that is not given is left out of
        %   the request:
        %       description - Description of the collab
        %       drive       - Whether the collab gets a drive
        %       chat        - Whether the collab gets a chat
        %       public      - Whether the collab is public
        %
        %   The documentation of the API asks for a token with the scopes
        %   clb.wiki.read and/or clb.wiki.write.

            arguments
                obj (1,1) ebrains.collab.api.CollabsClient
                name (1,1) string
                title (1,1) string
                collabOptions.description (1,1) string
                collabOptions.drive (1,1) logical
                collabOptions.chat (1,1) logical
                collabOptions.public (1,1) logical
            end

            payload = struct("name", name, "title", title);
            optionNames = string(fieldnames(collabOptions))';
            for optionName = optionNames
                payload.(optionName) = collabOptions.(optionName);
            end

            request = obj.initializeRequestMessage("POST", JSONPayload=jsonencode(payload));
            apiUri = ebrains.common.internal.buildApiUri(...
                ebrains.common.constant.CollabApiBaseUrl(), "collabs");
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode ~= matlab.net.http.StatusCode.Created
                obj.throwError("createCollab", response)
            end
        end

        function addTeamUser(obj, collabId, role, username)
        % addTeamUser - Add a user to the team of a collab
        %
        %   client.addTeamUser(collabId, role, username) gives the user a
        %   role in the collab. collabId is the name of the collab, as in
        %   the name field of the collabs that searchCollabs returns. role
        %   is "viewer", "editor" or "administrator".
        %
        %   The API documents these failures: 400 (Bad Request) when the
        %   user does not exist, 403 (Forbidden) when the account sending
        %   the request is not an administrator of the collab, and 404
        %   (Not Found) when the collab does not exist.

            arguments
                obj (1,1) ebrains.collab.api.CollabsClient
                collabId (1,1) string {mustBeNonzeroLengthText}
                role (1,1) string {mustBeMember(role, ["viewer", "editor", "administrator"])}
                username (1,1) string {mustBeNonzeroLengthText}
            end

            request = obj.initializeRequestMessage("PUT");
            apiUri = ebrains.common.internal.buildApiUri(...
                ebrains.common.constant.CollabApiBaseUrl(), ...
                ["collabs", collabId, "team", role, "users", username]);
            response = obj.sendRequest(request, apiUri);

            if response.StatusCode ~= matlab.net.http.StatusCode.NoContent
                obj.throwError("addTeamUser", response)
            end
        end
    end
end
