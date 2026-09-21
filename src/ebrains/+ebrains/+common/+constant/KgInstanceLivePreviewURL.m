function url = KgInstanceLivePreviewURL()
%KgInstanceLivePreviewURL - Base URL of the live preview page of a KG instance
%   URL = ebrains.common.constant.KgInstanceLivePreviewURL() returns the
%   URL, with a trailing slash, under which the Knowledge Graph Search
%   website serves the in-progress version of an instance. Append the UUID
%   of an instance to it to get the address of its page. The page renders
%   empty until you log in to EBRAINS in the browser.
%
%   See also KgInstanceViewURL, ebrains.kg.viewInstanceOnline

    url = "https://search.kg.ebrains.eu/live/";
end
