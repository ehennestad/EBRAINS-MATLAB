% Enter the UUID of a dataset version of interest. To find a dataset, go
% to https://search.kg.ebrains.eu and use the filters or run a free text
% search. If you select a dataset, the UUID can be found as the URI
% fragment of the URL, the part after the "#" symbol in the full URL.

% Example: Developmental mouse brain atlas (DeMBA)
dsvIdentifier = '8f1f65bb-44cb-4312-afd4-10f623f929b8';

% Specify the path for a jsonld to save all the metadata
saveFolder = fullfile(pwd, 'kg_metadata_example');
if ~isfolder(saveFolder); mkdir(saveFolder); end
fileName = sprintf('%s_metadata.jsonld', dsvIdentifier);

savePath = fullfile(saveFolder, fileName);

% Download the dataset version and follow 2 steps of linked metadata
[instance, collection] = ebrains.kg.downloadMetadata(...
    dsvIdentifier, ...
    "CollectionTargetFile", savePath, ...
    "NumLinksToResolve", 2);

disp(instance)

disp(collection)
