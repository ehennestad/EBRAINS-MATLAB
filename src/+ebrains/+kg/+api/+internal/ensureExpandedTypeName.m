function type = ensureExpandedTypeName(type)
    if ~startsWith(type, 'https://openminds.ebrains.eu/core/')
        type = "https://openminds.ebrains.eu/core/" + type;
    end
end
