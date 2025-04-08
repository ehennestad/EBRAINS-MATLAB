function linkedIdentifiers = extractLinkedIdentifiers(metadataNode)
    
    % Todo: Recursively iterate over struct instead of serializing

    jsonLdStr = openminds.internal.serializer.struct2jsonld(metadataNode);
    
    pattern = '(?<="@id":\s*")[^"]+(?=")';
    linkedIdentifiers = regexp(jsonLdStr, pattern, "match");
    linkedIdentifiers = unique(linkedIdentifiers);
end
