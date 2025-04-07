dsvIdentifier = '8f36d73a-befc-4aa5-b501-fc546e723f30';

response = ebrains.kg.downloadInstancesBulk(dsvIdentifier)

tic
DC = ebrains.kg.DatasetCollection(dsvIdentifier, 'type', 'DatasetVersion', "LinksToResolve", 1);
toc
% 1 link  : Elapsed time is 41.219617 seconds.
% 2 links : Elapsed time is 62.805063 seconds.

tic
collection = openminds.Collection;
kgNode = ebrains.kg.downloadInstance(dsvIdentifier);
omInstance = ebrains.kg.kg2om(kgNode, ...
    "ResolveLinksDepth", 2, ...
    "Collection", collection);
toc

% Todo: use bulk.

% 1 link  : Elapsed time is 13.356560 seconds.
% 2 links : Elapsed time is 24.140666 seconds.



% tic
% keys = DC.Nodes.keys();
% data = cell(1, numel(keys));
% omData = cell(1, numel(keys));
% 
% for i = 1:numel(keys)
%     instanceId = keys{i};
%     %instanceId = DC.Nodes(keys{i});
%     if startsWith(instanceId, "https://kg.ebrains.eu/api/instances/")
%         instanceId = strrep(instanceId, "https://kg.ebrains.eu/api/instances/", "");
%     else
%         continue
%     end
%     try
%         data{i} = ebrains.kg.downloadInstance(instanceId);
%         omData{i} = ebrains.kg.kg2om(data{i}, "ResolveLinksDepth", 1);
%     catch
%         fprintf('Failed to retrieve: %s\n', keys{i})
%     end
% end
% sum( cellfun('isempty', data) )
% toc
