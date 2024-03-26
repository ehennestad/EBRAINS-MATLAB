classdef ResultTypeInformation_data < ebrains.kgcore.JSONMapper
% ResultTypeInformation_data No description provided
% 
% ResultTypeInformation_data Properties:
%   empty - type: logical
%   http__schema_org_description - type: string
%   http__schema_org_identifier - type: string
%   http__schema_org_name - type: string
%   https__core_kg_ebrains_eu_vocab_meta_incomingLinks - type: array of IncomingLink
%   https__core_kg_ebrains_eu_vocab_meta_occurrences - type: int32
%   https__core_kg_ebrains_eu_vocab_meta_properties - type: array of Property
%   https__core_kg_ebrains_eu_vocab_meta_spaces - type: array of SpaceTypeInformation

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % empty - type: logical
        empty logical { ebrains.kgcore.JSONMapper.fieldName(empty,"empty") }
        % http__schema_org_description - type: string
        http__schema_org_description string { ebrains.kgcore.JSONMapper.fieldName(http__schema_org_description,"http://schema.org/description") }
        % http__schema_org_identifier - type: string
        http__schema_org_identifier string { ebrains.kgcore.JSONMapper.fieldName(http__schema_org_identifier,"http://schema.org/identifier") }
        % http__schema_org_name - type: string
        http__schema_org_name string { ebrains.kgcore.JSONMapper.fieldName(http__schema_org_name,"http://schema.org/name") }
        % https__core_kg_ebrains_eu_vocab_meta_incomingLinks - type: array of IncomingLink
        https__core_kg_ebrains_eu_vocab_meta_incomingLinks ebrains.kgcore.models.IncomingLink { ebrains.kgcore.JSONMapper.fieldName(https__core_kg_ebrains_eu_vocab_meta_incomingLinks,"https://core.kg.ebrains.eu/vocab/meta/incomingLinks"), ebrains.kgcore.JSONMapper.JSONArray }
        % https__core_kg_ebrains_eu_vocab_meta_occurrences - type: int32
        https__core_kg_ebrains_eu_vocab_meta_occurrences int32 { ebrains.kgcore.JSONMapper.fieldName(https__core_kg_ebrains_eu_vocab_meta_occurrences,"https://core.kg.ebrains.eu/vocab/meta/occurrences") }
        % https__core_kg_ebrains_eu_vocab_meta_properties - type: array of Property
        https__core_kg_ebrains_eu_vocab_meta_properties  { ebrains.kgcore.JSONMapper.fieldName(https__core_kg_ebrains_eu_vocab_meta_properties,"https://core.kg.ebrains.eu/vocab/meta/properties"), ebrains.kgcore.JSONMapper.JSONArray }
        % https__core_kg_ebrains_eu_vocab_meta_spaces - type: array of SpaceTypeInformation
        https__core_kg_ebrains_eu_vocab_meta_spaces ebrains.kgcore.models.SpaceTypeInformation { ebrains.kgcore.JSONMapper.fieldName(https__core_kg_ebrains_eu_vocab_meta_spaces,"https://core.kg.ebrains.eu/vocab/meta/spaces"), ebrains.kgcore.JSONMapper.JSONArray }
    end

    % Class methods
    methods
        % Constructor
        function obj = ResultTypeInformation_data(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.ResultTypeInformation_data
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class
