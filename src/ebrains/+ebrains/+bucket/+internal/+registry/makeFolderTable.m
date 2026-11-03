function folders = makeFolderTable(paths, buckets, prefixes, pinned, lastOpened)
% makeFolderTable - The Folders table of a registry from its columns
%
%   folders = ebrains.bucket.internal.registry.makeFolderTable(paths,
%   buckets, prefixes, pinned, lastOpened) returns a table with the
%   variables Path, Bucket, Prefix, Pinned and LastOpened, one row per
%   element of the columns.
%
%   See also ebrains.bucket.internal.registry.emptyRegistry

    arguments
        paths (:,1) string
        buckets (:,1) string
        prefixes (:,1) string
        pinned (:,1) logical
        lastOpened (:,1) datetime
    end

    lastOpened.TimeZone = "UTC";
    folders = table(paths, buckets, prefixes, pinned, lastOpened, ...
        'VariableNames', ["Path", "Bucket", "Prefix", "Pinned", "LastOpened"]);
end
