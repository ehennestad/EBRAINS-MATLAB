collabClient = ebrains.collaboratory.api.Collab();

isFinished = false;
offset = 0;

result = ebrains.collaboratory.models.CollabSearchResult.empty;

while ~isFinished
    [status, thisResult] = collabClient.searchCollab("limit", 200, "offset", offset);
    result = [result, thisResult]; %#ok<AGROW>
    offset = numel(result);
    
    if isempty(thisResult)
        isFinished = true;
    end
end

keep = startsWith([result.name], 'd-');

datasetCollabs = result(keep);

fprintf('Number of dataset collabs: %d\n', numel(datasetCollabs))

collabId = [datasetCollabs.name];
bucketSize = zeros(size(collabId));
for i = 1:numel(collabId)
    try
        bucketSize(i) = ebrains.bucket.getBucketSize(collabId(i));
        sizeWithUnitAsString = getDataSizeLabel( bucketSize(i) );
    
        fprintf("%s: %s\n", collabId(i), sizeWithUnitAsString)
    catch
        fprintf('Could not get bucket size for collab %s\n', collabId(i))
    end
end

T = table(collabId', bucketSize', 'VariableNames', {'Bucket Name', 'Bucket Size (bytes)'});

writetable(T, 'bucket_size_overview')
writetable(T, 'bucket_size_overview.xlsx')
