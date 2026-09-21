classdef InstanceView
%InstanceView - Pages that a Knowledge Graph instance can be opened on
%   InstanceView enumerates the pages that show an instance of the EBRAINS
%   Knowledge Graph (KG). VIEWINSTANCEONLINE accepts a member, or its name
%   as text, in its View option.
%
%   InstanceView members:
%       Search - The released version, on the KG Search site. This is the
%                only page that opens without an EBRAINS login.
%       Live   - The in-progress version, on the KG Search site. The page
%                stays empty until you log in to EBRAINS in the browser.
%       Editor - The instance in the KG Editor, which sends you to the
%                EBRAINS login before it opens the page.
%
%   InstanceView methods:
%       baseURL - URL that the page is served under
%
%   See also ebrains.kg.viewInstanceOnline

    enumeration
        Search
        Live
        Editor
    end

    methods
        function url = baseURL(obj)
        %baseURL - URL that the page is served under
        %   URL = baseURL(VIEW) returns the URL, with a trailing slash,
        %   that serves the page. Append the UUID of an instance to it to
        %   get the address of that instance on the page.

            arguments
                obj (1,1) ebrains.kg.enum.InstanceView
            end

            import ebrains.kg.enum.InstanceView

            switch obj
                case InstanceView.Search
                    url = ebrains.common.constant.KgInstanceViewURL();
                case InstanceView.Live
                    url = ebrains.common.constant.KgInstanceLivePreviewURL();
                case InstanceView.Editor
                    url = ebrains.common.constant.KgInstanceEditorURL();
                otherwise
                    % Every member above has a URL. A member added to the
                    % enumeration without one lands here rather than
                    % returning an unassigned url.
                    error("EBRAINS:KG:UnmappedInstanceView", ...
                        'No URL is defined for the "%s" view.', string(obj))
            end
        end
    end
end
