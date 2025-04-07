kg2OmIdentifierMap = ebrains.kg.kg2openminds.internal.getIdentifierMapping();
controlledKgIds = kg2OmIdentifierMap.keys();


tic
dsvIdentifier = '8f36d73a-befc-4aa5-b501-fc546e723f30';

kgNode = ebrains.kg.downloadInstance(dsvIdentifier);

[identifier, type] = ebrains.kg.internal.getNodeKeywords(kgNode, "id", "type");
% if ~isempty(options.Collection)
%     if options.Collection.isKey(identifier)
%         omInstance = options.Collection.get(identifier);
%         return
%     end
% end

omNode = ebrains.kg.kg2openminds.internal.convertKgNode(kgNode);
jsonLdStr = openminds.internal.serializer.struct2jsonld(omNode);

pattern = '(?<="@id":\s*")[^"]+(?=")';
IRIs = regexp(jsonLdStr, pattern, "match");
IRIs = setdiff(IRIs, controlledKgIds);

kgNodes = ebrains.kg.downloadInstancesBulk(IRIs);
disp(numel(kgNodes))

omNodes = ebrains.kg.kg2openminds.internal.convertKgNode(kgNodes);

jsonLdStr = openminds.internal.serializer.struct2jsonld(omNodes);
newIRIs = regexp(jsonLdStr, pattern, "match");
newIRIs = unique(newIRIs);

missingIRIs = setdiff(newIRIs, IRIs);
missingIRIs = setdiff(missingIRIs, controlledKgIds);

kgNodes = ebrains.kg.downloadInstancesBulk(missingIRIs);
kgNodes(cellfun('isempty', kgNodes))=[];
missingNodes = ebrains.kg.kg2openminds.internal.convertKgNode(kgNodes);
disp(numel(missingNodes))
omNodes = [{omNode}, omNodes, missingNodes];

% replace all controlled instance uuids
omNodes = ebrains.kg.kg2openminds.internal.replaceControlledInstanceIds(omNodes, kg2OmIdentifierMap);

jsonInstance = openminds.internal.serializer.struct2jsonld(omNodes);
openminds.internal.utility.filewrite('test_kg_download.jsonld', jsonInstance)
toc

C = openminds.Collection('test_kg_download.jsonld', 'LinkResolver', ebrains.kg.KGResolver());
