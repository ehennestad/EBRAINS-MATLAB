function url = buildInstanceViewURL(identifier, options)
% buildInstanceViewURL - Build the Knowledge Graph Search URL of an instance
%
%   Syntax:
%       url = ebrains.kg.internal.buildInstanceViewURL(identifier) returns
%       the address of the page that the Knowledge Graph Search website
%       serves for the released version of the instance.
%
%       url = ebrains.kg.internal.buildInstanceViewURL(identifier,
%       LivePreview=true) returns the address of the live preview page
%       instead, which shows the in-progress version.
%
%   Input Arguments
%       identifier : Identifier of a KG instance, given either as a bare
%                    UUID or as a full KG instance IRI.
%
%   Name-Value Arguments
%       LivePreview : Whether to build the live preview address. Default is
%                     false.
%
%   See also ebrains.kg.viewInstanceOnline,
%   ebrains.common.constant.KgInstanceViewURL,
%   ebrains.common.constant.KgInstanceLivePreviewURL

    arguments
        identifier (1,1) string
        options.LivePreview (1,1) logical = false
    end

    uuid = resolveUUID(identifier);

    if options.LivePreview
        baseURL = ebrains.common.constant.KgInstanceLivePreviewURL();
    else
        baseURL = ebrains.common.constant.KgInstanceViewURL();
    end

    url = baseURL + uuid;
end

function uuid = resolveUUID(identifier)
% resolveUUID - Reduce a KG instance identifier to the bare UUID

    % An instance that has never been saved to the Knowledge Graph carries a
    % blank node identifier, assigned locally by openMINDS_MATLAB. The
    % Knowledge Graph does not know it, so no page exists for it.
    if startsWith(identifier, "_:")
        error("EBRAINS:KG:BlankNodeIdentifier", ...
            ['"%s" is a blank node identifier, which is assigned locally ', ...
             'and is not known to the Knowledge Graph. Save the instance ', ...
             'to the Knowledge Graph before viewing it online.'], identifier)
    end

    uuid = ebrains.kg.api.internal.normalizeIdentifiers(identifier);

    uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-" + ...
                  "[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$";

    if isempty(regexp(uuid, uuidPattern, "once"))
        error("EBRAINS:KG:InvalidInstanceIdentifier", ...
            ['"%s" is not a Knowledge Graph instance identifier. Provide ', ...
             'the UUID of an instance, or its full instance IRI ("%s/<uuid>").'], ...
            identifier, ebrains.common.constant.KgInstanceIRIPrefix())
    end
end
