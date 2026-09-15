function IRI = KgInstanceIRIPrefix()
%KgInstanceIRIPrefix - Prefix of the IRIs that identify KG instances
%   IRI = ebrains.common.constant.KgInstanceIRIPrefix() returns the part
%   of a Knowledge Graph instance IRI that precedes the UUID, without a
%   trailing slash. The KG API clients strip it from identifiers before
%   sending a request.
%
%   See also KgNamespaceIRI, ebrains.kg.api.InstancesClient

    IRI = ebrains.common.constant.KgNamespaceIRI + "/instances";
end
