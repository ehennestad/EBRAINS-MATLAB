function registry = emptyRegistry()
% emptyRegistry - A registry of virtual buckets without a root, labels or folders
%
%   registry = ebrains.bucket.internal.registry.emptyRegistry() returns
%   the struct that the functions of this namespace pass around, as
%   spec/README.md#virtual-bucket-registry of the ebrains-bucket-sync
%   package lays the registry out:
%       Root    : Absolute path of the folder where new virtual buckets
%                 are made, or "" when none is set
%       Labels  : Table with one row per bucket that has a label, with
%                 the variables Bucket and Label (strings)
%       Folders : Table with one row per recorded folder, with the
%                 variables Path, Bucket and Prefix (strings), Pinned
%                 (logical) and LastOpened (datetime in UTC, NaT when the
%                 folder was recorded without being opened)
%
%   See also ebrains.bucket.internal.registry.readRegistry

    registry = struct( ...
        "Root", "", ...
        "Labels", table(strings(0, 1), strings(0, 1), 'VariableNames', ["Bucket", "Label"]), ...
        "Folders", ebrains.bucket.internal.registry.makeFolderTable( ...
            strings(0, 1), strings(0, 1), strings(0, 1), false(0, 1), NaT(0, 1, TimeZone="UTC")));
end
