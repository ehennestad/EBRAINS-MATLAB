function filePath = registryPath()
% registryPath - Where the registry of virtual buckets is, in the configuration folder
%
%   filePath = ebrains.bucket.internal.registry.registryPath() returns the
%   path of virtual-buckets.json in the configuration folder of the user,
%   which need not exist yet.
%
%   See also ebrains.bucket.internal.configFolder

    filePath = fullfile(ebrains.bucket.internal.configFolder(), "virtual-buckets.json");
end
