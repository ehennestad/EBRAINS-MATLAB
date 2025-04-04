collabInventoryFile = "path/to/collab_inventory_file";
targetFolder = "path/to/data_descriptor_target_folder";

collabIds = jsondecode(fileread(collabInventoryFile));
for i = 1:numel(collabIds)
    try
        bucketObjects = ebrains.bucket.listBucketObjects(collabIds{i});
    catch ME
        disp(ME.message)
        continue
    end

    if isempty(bucketObjects)
        continue
    end

    isDD = startsWith({bucketObjects.name}, 'data-descriptor');
    if any(isDD)
        try
            ddFilename = bucketObjects(isDD).name;
            if isfile( fullfile(targetFolder, ddFilename))
                continue % File was already downloaded
            end

            ebrains.bucket.getBucketObject(...
                collabIds{i}, ...
                bucketObjects(isDD).name, ...
                'TargetFolder', targetFolder)

            fprintf('Saved data descriptor (%s)\n', bucketObjects(isDD).name)
        catch ME
            disp(ME.message)
        end
    end
end
