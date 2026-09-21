classdef InstanceView
%InstanceView - Pages that a Knowledge Graph instance can be opened on
%   InstanceView enumerates the pages that show an instance of the EBRAINS
%   Knowledge Graph (KG). VIEWINSTANCEONLINE accepts a member, or its name
%   as text, in its View option.
%
%   InstanceView members:
%       Search  - The released version, on the KG Search site. This is the
%                 only page that opens without an EBRAINS login.
%       Preview - The in-progress version, on the KG Search site, shown as
%                 the card will look once published. Links to instances
%                 that are not released themselves may be inactive. The
%                 page stays empty until you log in to EBRAINS in the
%                 browser.
%       Editor  - The instance in the KG Editor, which sends you to the
%                 EBRAINS login before it opens the page.
%
%   InstanceView properties:
%       BaseURL - URL that the page is served under
%
%   See also ebrains.kg.viewInstanceOnline

    enumeration
        Search(ebrains.common.constant.KgInstanceViewURL())
        % The KG Search site serves the preview under /live/.
        Preview(ebrains.common.constant.KgInstanceLivePreviewURL())
        Editor(ebrains.common.constant.KgInstanceEditorURL())
    end

    properties
        % BaseURL - URL, with a trailing slash, that the page is served
        % under. Append the UUID of an instance to it to get the address
        % of that instance on the page.
        BaseURL
    end

    methods
        function obj = InstanceView(baseURL)
            obj.BaseURL = baseURL;
        end
    end
end
