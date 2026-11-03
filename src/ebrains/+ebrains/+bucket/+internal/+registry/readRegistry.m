function registry = readRegistry(filePath)
% readRegistry - Read the registry of virtual buckets, or an empty registry when there is no file
%
%   registry = ebrains.bucket.internal.registry.readRegistry() reads
%   virtual-buckets.json of the configuration folder (see
%   ebrains.bucket.internal.registry.registryPath), and
%   registry = ebrains.bucket.internal.registry.readRegistry(filePath)
%   reads another file. A file that is missing gives the registry of
%   ebrains.bucket.internal.registry.emptyRegistry.
%
%   A file that does not follow bucket-registry.schema.json of the
%   ebrains-bucket-sync package is an error (EBRAINS:Bucket:InvalidRegistry),
%   and so is one of a format version greater than this toolbox knows
%   (EBRAINS:Bucket:UnknownRegistryFormat); see
%   ebrains.bucket.internal.registry.parseRegistry.
%
%   See also ebrains.bucket.internal.registry.writeRegistry

    arguments
        filePath (1,1) string = ebrains.bucket.internal.registry.registryPath()
    end

    if ~isfile(filePath)
        registry = ebrains.bucket.internal.registry.emptyRegistry();
        return
    end
    text = ebrains.bucket.internal.metadata.readTextFile(filePath);
    registry = ebrains.bucket.internal.registry.parseRegistry(text, filePath);
end
