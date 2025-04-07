

apiClient = ebrains.kgcore.api.Basic();

[status, response] = apiClient.listTypes("RELEASED", "space", "controlled");

controlledTermTypes = string.empty;


for i = 1:numel(response.data)
    thisData = response.data{i};

    if startsWith(thisData.http___schema_org_identifier, ...
            "https://openminds.ebrains.eu/controlledTerms/")

        controlledTermTypes(end+1) = thisData.http___schema_org_identifier; %#ok<SAGROW>
    end
end

numTypes = numel(controlledTermTypes);
instances = cell(1, numTypes);

for i = 1:numTypes
    [status, response] = apiClient.listInstances("RELEASED", controlledTermTypes{i}, "space", "controlled");
    numInstances = numel(response.data);
    [kgIds, omIds] = deal(cell(1, numInstances));
    for j = 1:numel(response.data)
        thisData = response.data(j);
        if iscell(thisData)
            thisData = thisData{1};
        end
        kgIds{j} = thisData.x_id;
        omIds{j} = thisData.http___schema_org_identifier(...
            startsWith(thisData.http___schema_org_identifier, 'https://openminds'));
    end
    instances{i} = struct('kg', kgIds, 'om', omIds);
    [instances{i}(:).type] = deal(controlledTermTypes{i});
end

allInstances = [instances{:}];
for i = 1:numel(allInstances)
    if isempty(allInstances(i).om)
        allInstances(i).om = '';
    elseif iscell(allInstances(i).om) && iscell(allInstances(i).om{1})
        allInstances(i).om = allInstances(i).om{1};
    end
end

T = struct2table(allInstances);
T.kg = string(T.kg);
T.om = string(T.om);
T.type = string(T.type);

S = table2struct(T);
utility.filewrite('kg2om_identifier_loopkup.json', jsonencode(S, 'PrettyPrint', true))

keys = T.kg;
values = T.om;
D = dictionary(keys, values);

tic
for i = 1:1
    D(keys(randi(numel(keys))));
end
toc
