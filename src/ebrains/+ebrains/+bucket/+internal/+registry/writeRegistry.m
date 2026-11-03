function writeRegistry(registry, filePath)
% writeRegistry - Write the registry of virtual buckets so that an interrupted write leaves the old file
%
%   ebrains.bucket.internal.registry.writeRegistry(registry) writes
%   virtual-buckets.json of the configuration folder, creating the folder
%   if needed, and
%   ebrains.bucket.internal.registry.writeRegistry(registry, filePath)
%   writes another file. The text is that of
%   ebrains.bucket.internal.registry.formatRegistry.
%
%   See also ebrains.bucket.internal.registry.readRegistry

    arguments
        registry (1,1) struct
        filePath (1,1) string = ebrains.bucket.internal.registry.registryPath()
    end

    ebrains.bucket.internal.metadata.writeTextFile(filePath, ...
        ebrains.bucket.internal.registry.formatRegistry(registry))
end
