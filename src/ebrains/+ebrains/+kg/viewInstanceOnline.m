function viewInstanceOnline(target, options)
% viewInstanceOnline - Open the page of a KG instance in a web browser
%
%   Syntax:
%       ebrains.kg.viewInstanceOnline(target) opens the instance on the
%       Knowledge Graph Search site, which shows its released version.
%
%       ebrains.kg.viewInstanceOnline(target, View=VIEW) opens it on the
%       given page instead. VIEW must be:
%           "Search"  - (default) The released version, on the KG Search
%                       site. This is the only page that opens without
%                       an EBRAINS login.
%           "Preview" - The in-progress version, on the KG Search site,
%                       shown as the card will look once published. The
%                       page stays empty until you log in to EBRAINS in
%                       the browser.
%           "Editor"  - The instance in the KG Editor, which sends you
%                       to the EBRAINS login before it opens the page.
%
%   Input Arguments
%       target : Instance to view, given either as a scalar openminds.Node
%                or as the identifier of a KG instance. An identifier is
%                either a bare UUID or a full KG instance IRI.
%
%   Name-Value Arguments
%       View   : Page to open the instance on, as an
%                ebrains.kg.enum.InstanceView or its name as text.
%       Opener : Function that is called with the address to open. Meant
%                for tests and custom browsers; WEB is called otherwise.
%
%   Example:
%       % Open a dataset version on the KG Search site, given its UUID
%       ebrains.kg.viewInstanceOnline("08ab00ea-3e19-4300-9d9f-c0ef0ec8e445")
%
%       % Open the same instance in the KG Editor
%       ebrains.kg.viewInstanceOnline("08ab00ea-3e19-4300-9d9f-c0ef0ec8e445", ...
%           View="Editor")
%
%   See also ebrains.kg.enum.InstanceView,
%   ebrains.kg.internal.buildInstanceViewURL, web

    arguments
        target
        options.View (1,1) ebrains.kg.enum.InstanceView = "Search"
        options.Opener (1,1) function_handle = @web
    end

    identifier = resolveIdentifier(target);

    url = ebrains.kg.internal.buildInstanceViewURL(identifier, View=options.View);

    options.Opener(url);
end

function identifier = resolveIdentifier(target)
% resolveIdentifier - Get the KG identifier of an instance or text target
%
%   openMINDS_MATLAB is an optional dependency of this toolbox. isa returns
%   false when its classes are not on the path, so a target that is neither
%   an openMINDS instance nor text reaches the error below either way.

    if isa(target, "openminds.Node")
        if ~isscalar(target)
            error("EBRAINS:KG:NonScalarTarget", ...
                ['A %s array of %d elements cannot be viewed as one page. ', ...
                 'Pass a single instance.'], class(target), numel(target))
        end
        identifier = target.id;
    elseif isstring(target) || ischar(target)
        identifier = string(target);
        if ~isscalar(identifier)
            error("EBRAINS:KG:NonScalarTarget", ...
                ['A string array of %d elements cannot be viewed as one ', ...
                 'page. Pass a single identifier.'], numel(identifier))
        end
    else
        error("EBRAINS:KG:InvalidTarget", ...
            ['A target of class %s cannot be viewed online. Pass an ', ...
             'openMINDS instance, or the UUID of a Knowledge Graph ', ...
             'instance as text.'], class(target))
    end
end
