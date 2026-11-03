function registry = updateRegistry(changeFcn)
% updateRegistry - Read the registry of virtual buckets, change it and write it back
%
%   registry = ebrains.bucket.internal.registry.updateRegistry(changeFcn)
%   reads virtual-buckets.json of the configuration folder, applies
%   changeFcn(registry), which returns the changed registry, writes the
%   result and returns it. Reading and writing raise the errors of
%   ebrains.bucket.internal.registry.readRegistry and writeRegistry.
%
%   Example:
%       ebrains.bucket.internal.registry.updateRegistry( ...
%           @(registry) ebrains.bucket.internal.registry.setLabel(registry, "d-1", "Mouse V1"))
%
%   See also ebrains.bucket.internal.registry.recordFolderOpened

    arguments
        changeFcn (1,1) function_handle
    end

    registry = ebrains.bucket.internal.registry.readRegistry();
    registry = changeFcn(registry);
    ebrains.bucket.internal.registry.writeRegistry(registry)
end
