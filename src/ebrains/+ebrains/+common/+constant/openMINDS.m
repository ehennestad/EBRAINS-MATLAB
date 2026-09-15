classdef openMINDS
%openMINDS - Namespace IRIs of the openMINDS metadata model
%   openMINDS holds the IRI prefixes under which openMINDS types,
%   instances and properties are identified. All are constant.
%
%   openMINDS properties:
%       BaseIRI        - Root of the openMINDS namespace
%       TypePrefix     - Prefix of type IRIs
%       InstancePrefix - Prefix of instance IRIs
%       PropertyPrefix - Prefix of property IRIs
%
%   See also KgNamespaceIRI, ebrains.kg.api.InstancesClient

    properties (Constant)
        BaseIRI = "https://openminds.om-i.org"                       % Root of the openMINDS namespace
        TypePrefix = "https://openminds.om-i.org/types/"             % Prefix of type IRIs
        InstancePrefix = "https://openminds.om-i.org/instances/"     % Prefix of instance IRIs
        PropertyPrefix = "https://openminds.om-i.org/props/"         % Prefix of property IRIs
    end
end
