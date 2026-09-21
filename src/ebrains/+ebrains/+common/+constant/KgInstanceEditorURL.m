function url = KgInstanceEditorURL()
%KgInstanceEditorURL - Base URL of the editor page of a KG instance
%   URL = ebrains.common.constant.KgInstanceEditorURL() returns the URL,
%   with a trailing slash, under which the Knowledge Graph Editor serves
%   an instance. Append the UUID of an instance to it to get the address
%   of its page. The editor sends you to the EBRAINS login before it
%   opens the page.
%
%   See also KgInstanceViewURL, ebrains.kg.viewInstanceOnline

    url = "https://editor.kg.ebrains.eu/instances/";
end
