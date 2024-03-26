% Run startup to configure the package's MATLAB paths
%startup

specFile = preprocessSpec("https://data-proxy.ebrains.eu/api/openapi.json");

% Create a builder object
c = openapi.build.Client;
% Set the package name, defaults to "OpenAPIClient"
c.packageName = "ebrains.dataproxy";
% Set the path to the spec., this may also be a HTTP URL
c.inputSpec = specFile;
% Set a directory where the results will be stored
c.output = fullfile("/Users/eivihe/Code/MATLAB/Nesys/EBRAINS/src/services/DataProxy");
% Trigger the build process
c.build;


function specFilePath = preprocessSpec(urlSpec)
    
    folderPath = fileparts(mfilename('fullpath'));
    specFilePath = fullfile(folderPath, 'dp_openapi.json');

    websave(specFilePath, urlSpec);
    
    jsonStr = fileread(specFilePath);

    % Change openapi version to 3.0.0
    jsonStr = strrep(jsonStr, '"openapi":"3.1.0"', '"openapi":"3.0.0"');

    % Change default server uri
    jsonStr = strrep(jsonStr, '{"url":"/api"}', '{"url":"https://data-proxy.ebrains.eu//api"}');

    jsonStr = fixParameterDescriptions(jsonStr);

    remap = dictionary(...
        ["get_permalinks_permalinks_get"
        "create_permalink_permalinks_post"
        "access_permalink_ressource_permalinks__permalink_id__get"
        "update_permalink_permalinks__permalink_id__put"
        "delete_permalink_ressource_permalinks__permalink_id__delete"
        "dataset_stat_v1_datasets__dataset_id__stat_get"
        "get_dataset_v1_datasets__dataset_id__get"
        "request_dataset_access_v1_datasets__dataset_id__post"
        "download_dataset_object_v1_datasets__dataset_id___object_name__get"
        "list_buckets_v1_buckets_get"
        "create_bucket_v1_buckets_post"
        "list_bucket_objects_v1_buckets__bucket_name__get"
        "update_bucket_v1_buckets__bucket_name__put"
        "delete_bucket_v1_buckets__bucket_name__delete"
        "bucket_stat_v1_buckets__bucket_name__stat_get"
        "copy_bucket_v1_buckets__bucket_name__copy_put"
        "copy_object_v1_buckets__bucket_name___object_name__copy_put"
        "download_bucket_v1_buckets__bucket_name___object_name__get"
        "upload_file_v1_buckets__bucket_name___object_name__put"
        "delete_v1_buckets__bucket_name___object_name__delete"
        "rename_object_v1_buckets__bucket_name___object_name__patch"
        "update_bucket_acl_v1_acl__bucket_name__post"
        "get_bucket_acl_v1_admin_buckets__bucket_name__acl_get"], ...
        ...
        ["list_permalinks"
        "create_permalink"
        "access_permalink_resource"
        "update_permalink"
        "delete_permalink"
        "get_bucket_stats"
        "list_dataset_objects"
        "request_dataset_access"
        "download_dataset_object"
        "list_buckets"
        "create_bucket"
        "list_bucket_objects"
        "update_bucket"
        "delete_bucket"
        "get_bucket_stat"
        "copy_bucket"
        "copy_object"
        "get_download_url"
        "get_upload_url"
        "delete_object"
        "rename_object"
        "update_bucket_acl"
        "get_bucket_acl"] ...
    );

    for iKey = remap.keys()'
        jsonStr = strrep(jsonStr, iKey, remap(iKey));
    end


    utility.filewrite(specFilePath, jsonStr)
end

function jsonStr = fixParameterDescriptions(jsonStr)


    % Get all descriptions for parameters:
    matches = regexp(jsonStr, '"description":"Parameters.*?,"operationId".*?,', 'match');

    [parameters, operationIDs] = extractParametersAndOperationID(matches);

    jsonStrSplit = strsplit(jsonStr, '"tags":');

    for i = 1:numel(jsonStrSplit)
        hasOperationId = cellfun(@(c) contains(jsonStrSplit{i}, c), operationIDs);

        if any( hasOperationId )
            % Which operation id?
            iParameters = parameters{hasOperationId};

            for j = 1:numel(iParameters)
                oldExpression = sprintf('"name":"%s"', iParameters{j}{1});
                newExpression = sprintf('%s,"description":"%s"', oldExpression, iParameters{j}{2});
                jsonStrSplit{i} = regexprep(jsonStrSplit{i}, oldExpression, newExpression);
            end

            expression = '"description":"Parameters.*?,(?="operationId")';
            %regexp(jsonStrSplit{i}, expression, 'match')
            jsonStrSplit{i} = regexprep(jsonStrSplit{i}, expression, '');
        end
    end

    jsonStr = strjoin(jsonStrSplit, '"tags":');
end


% Get old operation ids:
    % % json = webread(urlSpec);
    % % A = struct2cell( json.paths );
    % % B = cellfun(@(c) struct2cell(c), A, 'uni', false);
    % % C = cat(1, B{:});
    % % 
    % % hasDeprecated = cellfun(@(c) isfield(c, 'deprecated'), C, 'UniformOutput', true);
    % % isDeprecated = cellfun(@(c) c.deprecated, C(hasDeprecated), 'UniformOutput', true);
    % % assert( all(isDeprecated) )
    % % C = C(~hasDeprecated);
    % % 
    % % summaries = cellfun(@(c) c.summary, C, 'UniformOutput', false);
    % % operationId = cellfun(@(c) c.operationId, C, 'UniformOutput', false);
