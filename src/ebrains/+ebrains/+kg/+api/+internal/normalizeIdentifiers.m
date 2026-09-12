function identifiers = normalizeIdentifiers(identifiers)
% normalizeIdentifiers - Strip the KG instance IRI prefix from identifiers
%
% Syntax:
%   identifiers = ebrains.kg.api.internal.normalizeIdentifiers(identifiers)
%   returns the bare UUID for every identifier given as a full KG instance
%   IRI. Identifiers that do not carry the prefix are returned unchanged.
%
% Input Arguments:
%   identifiers - String array of KG instance identifiers, each either a
%                 full instance IRI or a bare UUID.
%
% Output Arguments:
%   identifiers - String array of the same shape holding bare UUIDs.

    arguments
        identifiers string
    end

    iriPrefix = ebrains.common.constant.KgInstanceIRIPrefix + "/";

    hasPrefix = startsWith(identifiers, iriPrefix);
    identifiers(hasPrefix) = extractAfter(identifiers(hasPrefix), iriPrefix);
end
