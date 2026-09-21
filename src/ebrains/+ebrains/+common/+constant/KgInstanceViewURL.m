function url = KgInstanceViewURL()
%KgInstanceViewURL - Base URL of the released page of a KG instance
%   URL = ebrains.common.constant.KgInstanceViewURL() returns the URL,
%   with a trailing slash, under which the Knowledge Graph Search website
%   serves the released version of an instance. Append the UUID of an
%   instance to it to get the address of its page.
%
%   See also KgInstanceLivePreviewURL, ebrains.kg.viewInstanceOnline

    url = "https://search.kg.ebrains.eu/instances/";
end
