function createVirtualBucket(bucketName, virtualBucketRootPath, options)
%
%
%   Example:
%      bucketName = "d-ca602c23-364a-4c9b-943b-87d1b09a5821";
%      virtualBucketRootPath = "data_demo";
%      sharebrain.createVirtualBucket(bucketName, virtualBucketRootPath)

    arguments
        bucketName (1,1) string
        virtualBucketRootPath (1,1) string
        options.Verbose = true
    end

    S = ebrains.bucket.listBucketObjects(bucketName, "Verbose", options.Verbose);

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end
    
    for i = 1:numel(S)
        objectName = S(i).name;
        filePath = fullfile(virtualBucketRootPath, objectName);
        parentFolderName = fileparts(objectName);
        if ~isempty(parentFolderName)
            parentFolderPath = fileparts(filePath);
            if ~isfolder(parentFolderPath); mkdir(parentFolderPath); end
        end
        filePath = strrep(filePath, ' ', '\ ');
        [status, msg] = system( sprintf('touch %s', filePath ));
        
        if mod(i, 100) == 0 || i == numel(S)
            if options.Verbose
                fprintf("Created %d/%d virtual files\n", i, numel(S))
            end
        end
    end
end
