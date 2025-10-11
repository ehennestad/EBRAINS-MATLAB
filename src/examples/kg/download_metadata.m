% Prerequisites: 
%  - openMINDS Metadata Toolbox (install via Add-On Manager)
%  - openminds-kg-sync 

% Set openminds version to 3, as this is currently used in the EBRAINS 
% Knowledge Graph. Please note: it is important to run `clear all` whenever
% changing the openMINDS version to avoid conflicts from class definitions of
% metadata types from other versions being loaded in memory.
clear all;
openminds.version(3);

% Enter the UUID of a dataset version of interest. To find a dataset, go
% to https://search.kg.ebrains.eu and use the filters or run a free text
% search. If you select a dataset, the UUID can be found as the URI
% fragment of the URL, the part after the "#" symbol in the full URL.

% Example: Developmental mouse brain atlas (DeMBA)
dsvIdentifier = '08ab00ea-3e19-4300-9d9f-c0ef0ec8e445';

dsv = kgpull(dsvIdentifier, "NumLinksToResolve", 2);

% Specify the path for a jsonld to save all the metadata
saveFolder = fullfile(pwd, 'kg_metadata_example');
if ~isfolder(saveFolder); mkdir(saveFolder); end
fileName = sprintf('%s_metadata.jsonld', dsvIdentifier);

savePath = fullfile(saveFolder, fileName);

% Create a collection and save to the specified path
collection = openminds.Collection(dsv);
collection.save(savePath)

disp(dsv)
disp(collection)
