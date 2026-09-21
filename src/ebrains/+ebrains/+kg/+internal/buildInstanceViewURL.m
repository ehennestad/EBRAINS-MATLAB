function url = buildInstanceViewURL(identifier, options)
% buildInstanceViewURL - Build the address of a KG instance on a web page
%
%   Syntax:
%       url = ebrains.kg.internal.buildInstanceViewURL(identifier) returns
%       the address of the instance on the Knowledge Graph Search site,
%       which shows its released version.
%
%       url = ebrains.kg.internal.buildInstanceViewURL(identifier,
%       View=VIEW) returns its address on the given page instead.
%
%   Input Arguments
%       identifier : Identifier of a KG instance, given either as a bare
%                    UUID or as a full KG instance IRI.
%
%   Name-Value Arguments
%       View : Page to build the address for, as an
%              ebrains.kg.enum.InstanceView or its name as text. Default
%              is "Search".
%
%   See also ebrains.kg.viewInstanceOnline, ebrains.kg.enum.InstanceView

    arguments
        identifier (1,1) string
        options.View (1,1) ebrains.kg.enum.InstanceView = "Search"
    end

    uuid = resolveUUID(identifier);

    url = options.View.BaseURL + uuid;
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
