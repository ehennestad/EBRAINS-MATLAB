% List the dataset collabs (names starting with "d-") and write an
% overview of the size of their buckets.

PAGE_SIZE = 200;

collabClient = ebrains.collab.api.CollabsClient();

collabs = struct.empty;
offset = 0;
isFinished = false;

while ~isFinished
    page = collabClient.searchCollabs(limit=PAGE_SIZE, offset=offset);
    if isempty(page)
        isFinished = true;
    else
        collabs = [collabs; page(:)]; %#ok<AGROW>
        offset = numel(collabs);
    end
end

collabNames = string({collabs.name});
datasetCollabNames = collabNames(startsWith(collabNames, "d-"));

fprintf('Number of dataset collabs: %d\n', numel(datasetCollabNames))

bucketSize = zeros(size(datasetCollabNames));
for i = 1:numel(datasetCollabNames)
    try
        bucketSize(i) = ebrains.bucket.getBucketSize(datasetCollabNames(i));
        sizeWithUnitAsString = ebrains.util.getDataSizeLabel(bucketSize(i));

        fprintf("%s: %s\n", datasetCollabNames(i), sizeWithUnitAsString)
    catch
        fprintf('Could not get bucket size for collab %s\n', datasetCollabNames(i))
    end
end

T = table(datasetCollabNames', bucketSize', 'VariableNames', {'Bucket Name', 'Bucket Size (bytes)'});

writetable(T, 'bucket_size_overview')
writetable(T, 'bucket_size_overview.xlsx')
