TYPES_IGNORE = "QuantitativeValue"; % For some reason, the whole program got stuck
SPACE = "myspace";
SERVER = "PREPROD";

kgClient = ebrains.kg.api.InstancesClient();

types = kgClient.listTypes("space", SPACE, "Server", SERVER);

if isempty(types)
    fprintf('No types found in space "%s" on server "%s"\n', SPACE, SERVER)
    return
end

struct2table(types) % Display types

% Fetch instances
instances = cell(1, numel(types));
for iType = 1:numel(types)
    typeName = types(iType).http___schema_org_name;
    if ismember(typeName, TYPES_IGNORE)
        continue
    end
    typeIRI = types(iType).http___schema_org_identifier;
    instances{iType} = kgClient.listInstances(typeIRI, space=SPACE, stage="IN_PROGRESS", Server=SERVER);
    fprintf('Retrieved instances for type %s\n', typeName)
end

% Build a list of identifiers:
numInstances = sum( cellfun(@numel, instances) );
identifiers = repmat("", 1, numInstances);
count = 0;

for iType = 1:numel(types)
    for jInstance = 1:numel(instances{iType})
        
        if isstruct(instances{iType}) % normalize to cell array
            instances{iType} = num2cell(instances{iType});
        end

        count = count + 1;
        identifiers(count) = instances{iType}{jInstance}.x_id;
    end
end

% Delete instances by their uuids
for i = 1:numel(identifiers)
    try
        uuid = extractAfter(identifiers(i), ebrains.common.constant.KgInstanceIRIPrefix + "/");
        kgClient.deleteInstance(uuid, "Server", SERVER)
        fprintf('Deleted instance  with identifier %s\n', identifiers(i))
    catch ME
        warning(ME.identifier, "Failed for instance with identifier '%s' with error: \n%s", identifiers(i), ME.message)
    end
end
