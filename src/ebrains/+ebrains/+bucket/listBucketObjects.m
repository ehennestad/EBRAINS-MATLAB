function completeObjectList = listBucketObjects(bucketName, options)
% listBucketObjects - Get info for all objects of a bucket
%
%   Syntax:
%       S = ebrains.bucket.listBucketObjects(bucketName) returns a struct
%           array where each element contains info about a bucket object
%           (i.e a file)
%
%       S = ebrains.bucket.listBucketObjects(bucketName, Prefix=PREFIX)
%           returns only the objects whose name starts with PREFIX. A
%           dataset that shares its bucket with other datasets is addressed
%           this way, as <bucket>?prefix=<folder>/ in its repository IRI.
%
%   Input Arguments
%       bucketName : Name of the bucket to get object information from
%
%   Name-Value Arguments
%       Prefix  : Only list objects whose name starts with this text.
%                 Default is "", which lists every object.
%       Verbose : Print progress while the pages of the listing arrive.
%       Client  : ebrains.bucket.api.BucketsClient that sends the requests.
%                 Meant for tests and custom clients; a default client is
%                 created otherwise.

    arguments
        bucketName (1,1) string
        options.Prefix (1,1) string = ""
        options.Verbose (1,1) logical = false
        options.Client (1,1) ebrains.bucket.api.BucketsClient = ebrains.bucket.api.BucketsClient()
    end

    client = options.Client;

    % The stat endpoint reports the object count in one request, which is
    % what tells the paging loop below when the listing is complete. With a
    % prefix the count is an upper bound, because it covers the whole
    % bucket, and the listing ends on the first empty page instead.
    bucketStat = client.getBucketStat(bucketName);
    nTotalObjects = bucketStat.objects_count;

    pageSize = 10000;
    marker = "";

    finished = false;
    completeObjectList = struct.empty;

    tBegin = tic;
    while ~finished

        if options.Verbose
            fprintf('Sending request for bucket objects... ')
        end

        % The first page has no marker; later pages start after the last
        % object of the page before.
        queryParameters = struct("limit", pageSize);
        if options.Prefix ~= ""
            queryParameters.prefix = options.Prefix;
        end
        if marker ~= ""
            queryParameters.marker = marker;
        end
        queryArguments = namedargs2cell(queryParameters);
        page = client.listObjects(bucketName, queryArguments{:});
        objectList = page.objects;

        if isempty(completeObjectList)
            completeObjectList = objectList;
        else
            completeObjectList = cat(1, completeObjectList, objectList);
        end

        if options.Verbose
            fprintf('Retrieved %d/%d objects.\n', numel(completeObjectList), nTotalObjects)
        end

        % The data proxy returns fewer objects per page than requested, so
        % a short page does not mean the last one. The listing is complete
        % when it holds as many objects as the bucket reports, or when a
        % page comes back empty.
        if isempty(objectList)
            finished = true;
        else
            marker = objectList(end).name;
            finished = numel(completeObjectList) >= nTotalObjects;
        end
    end

    tElapsed = toc(tBegin);
    if options.Verbose
        fprintf('Retrieved %d objects in %.2f seconds.\n', ...
            numel(completeObjectList), tElapsed )
    end
end
