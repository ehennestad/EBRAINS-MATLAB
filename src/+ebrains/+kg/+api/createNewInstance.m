function out = createNewInstance(space, payloadJson, opts, serverOpts)
% createNewInstance  Call the "Create new instance" POST endpoint with a JSON string payload.
%
% REQUIRED INPUTS
%   space         - string, space name (required by API)
%   payloadJson   - string, JSON document to POST (already serialized)
%
% NAME-VALUE OPTIONS (all optional, pass as opts.<name>)
%   returnIncomingLinks   - logical
%   incomingLinksPageSize - scalar integer (int64)
%   returnPayload         - logical
%   returnPermissions     - logical
%   returnAlternatives    - logical
%   returnEmbedded        - logical
%
% RETURNS
%   out struct with fields:
%     StatusCode  - double HTTP status code
%     Headers     - matlab.net.http.HeaderField array
%     BodyRaw     - raw response body (as returned by MATLAB)
%     BodyText    - char/string form (if convertible)
%     BodyJSON    - decoded JSON (if response is JSON and decodes)
%
% NOTE
%   This function does not infer/guess the endpoint path.
    
    arguments
        space             (1,1) string {mustBeNonzeroLengthText}
        payloadJson       (1,1) string {mustBeNonzeroLengthText}
        opts.returnIncomingLinks    logical 
        opts.incomingLinksPageSize  int64 
        opts.returnPayload          logical 
        opts.returnPermissions      logical 
        opts.returnAlternatives     logical 
        opts.returnEmbedded         logical
        serverOpts.Server (1,1) string {mustBeMember(serverOpts.Server, ["prod", "preprod"])} = "prod"
    end
    
    import matlab.net.*
    import matlab.net.http.*
    import matlab.net.http.field.AuthorizationField

    serverUrl = ebrains.common.constant.KGCoreApiBaseURL("Server", serverOpts.Server);
    baseApiUrl = serverUrl + "/instances";
    
    % Assemble query parameters (required + present optionals)
    q = [ QueryParameter('space', space) ];
    
    if isfield(opts, 'returnIncomingLinks'),   q(end+1) = QueryParameter('returnIncomingLinks',   logical(opts.returnIncomingLinks)); end
    if isfield(opts, 'incomingLinksPageSize') && opts.incomingLinksPageSize ~= 0
        q(end+1) = QueryParameter('incomingLinksPageSize',   opts.incomingLinksPageSize);
    end
    if isfield(opts, 'returnPayload'),         q(end+1) = QueryParameter('returnPayload',         logical(opts.returnPayload)); end
    if isfield(opts, 'returnPermissions'),     q(end+1) = QueryParameter('returnPermissions',     logical(opts.returnPermissions)); end
    if isfield(opts, 'returnAlternatives'),    q(end+1) = QueryParameter('returnAlternatives',    logical(opts.returnAlternatives)); end
    if isfield(opts, 'returnEmbedded'),        q(end+1) = QueryParameter('returnEmbedded',        logical(opts.returnEmbedded)); end
    

    uri = URI(baseApiUrl, q);
    
    authClient = ebrains.iam.AuthenticationClient.instance();

    % Prepare request
    hdrs = [ ...
        HeaderField('Content-Type','application/json'), ...
        HeaderField('Accept','application/json') ...
        AuthorizationField("Authorization", "Bearer " + authClient.AccessToken) ...
        ];

    body = matlab.net.http.MessageBody();
    body.Payload = char(payloadJson);

    req  = RequestMessage('post', hdrs, body);
    
    try
        resp = req.send(uri);
    
        % Prepare output
        out.StatusCode = double(resp.StatusCode);
        out.Headers    = resp.Header;
        out.BodyRaw    = resp.Body.Data;
    
        % Try to provide text form
        try
            out.BodyText = resp.Body.string();
        catch
            try
                out.BodyText = string(resp.Body.Data);
            catch
                out.BodyText = "";
            end
        end
    
        % Try JSON decode if applicable
        out.BodyJSON = [];
        ct = resp.getFields('Content-Type');
        if ~isempty(ct)
            ctv = string(ct.Value);
            if any(contains(lower(ctv), "application/json"))
                try
                    out.BodyJSON = jsondecode(char(out.BodyText));
                catch
                    % Leave BodyJSON empty if not decodable
                end
            end
        end
    
    catch ME
        % Return error details without throwing, so callers can inspect
        out.StatusCode = NaN;
        out.Headers    = [];
        out.BodyRaw    = [];
        out.BodyText   = "";
        out.BodyJSON   = [];
        out.Error      = struct('identifier', ME.identifier, 'message', ME.message);
    end
end
