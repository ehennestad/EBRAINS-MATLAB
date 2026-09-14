classdef CollabsClient < ebrains.common.internal.HttpClient
% CollabsClient - Client for the collab endpoints of the EBRAINS Collaboratory
%
%   Each method mirrors one endpoint under /collabs of the Collaboratory
%   REST API.
%
%   Example:
%       client = ebrains.collab.api.CollabsClient();
%       collabs = client.searchCollabs(search="dataset", limit=50);
%
%   See also ebrains.common.constant.CollabApiBaseUrl

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
    end
end
