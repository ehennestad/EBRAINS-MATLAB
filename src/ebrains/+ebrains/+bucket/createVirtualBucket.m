function createVirtualBucket(bucketName, virtualBucketRootPath, options)
% createVirtualBucket - Create a virtual bucket locally.
%
%   This function will create a dataset with dummy files (i.e empty files)
%   for all objects in a bucket.
%
%   Syntax:
%       ebrains.bucket.createVirtualBucket(bucketName, virtualBucketRootPath)
%           creates the virtual dataset for a bucket in the folder 
%           specified by virtualBucketRootPath

    arguments
        bucketName (1,1) string
        virtualBucketRootPath (1,1) string
        options.Verbose = false
    end

    S = ebrains.bucket.listBucketObjects(bucketName, "Verbose", options.Verbose);

    if ~isfolder(virtualBucketRootPath); mkdir(virtualBucketRootPath); end
    
    for i = 1:numel(S)
        objectName = S(i).name;
        filePath = fullfile(virtualBucketRootPath, objectName);
        [parentFolderName, name, fileExtension] = fileparts(objectName);
        if isempty(fileExtension)
            if ~isfolder(filePath); mkdir(filePath); end
            continue
        elseif ~isempty(parentFolderName)
            parentFolderPath = fileparts(filePath);
            if ~isfolder(parentFolderPath); mkdir(parentFolderPath); end
        end
        filePath = strrep(filePath, ' ', '\ ');
        [status, msg] = system( sprintf('touch "%s"', filePath ));
        
        if mod(i, 100) == 0 || i == numel(S)
            if options.Verbose
                fprintf("Created %d/%d virtual files\n", i, numel(S))
            end
        end
    end
end
