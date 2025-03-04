function renameObject(bucketName, objectName, targetName)
    arguments
        bucketName (1,1) string
        objectName (1,1) string
        targetName (1,1) string
    end

    if startsWith(objectName, '/')
        objectName = extractAfter(objectName, 1);
    end
    if startsWith(targetName, '/')
        targetName = extractAfter(targetName, 1);
    end

    requiredArgs = ebrains.dataproxy.models.RenameObjectPayload(...
        'rename', ...
        ebrains.dataproxy.models.RenameObjectSetting('target_name', targetName));

    bucketApiClient = ebrains.dataproxy.api.Buckets();
    [code, result, response] = bucketApiClient.renameObject(...
        bucketName, objectName, requiredArgs);
end
