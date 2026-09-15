function IRI = KgNamespaceIRI()
%KgNamespaceIRI - Namespace of the IRIs minted by the Knowledge Graph
%   IRI = ebrains.common.constant.KgNamespaceIRI() returns the namespace,
%   without a trailing slash, from which the identifiers of KG instances
%   are built.
%
%   See also KgInstanceIRIPrefix

    IRI = "https://kg.ebrains.eu/api";
end
