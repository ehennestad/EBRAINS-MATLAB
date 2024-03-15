classdef ResultNormalizedJsonLd_data < ebrains.kgcore.JSONMapper
% ResultNormalizedJsonLd_data No description provided
% 
% ResultNormalizedJsonLd_data Properties:
%   id - type: JsonLdId
%   empty - type: logical

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % id - type: JsonLdId
        id ebrains.kgcore.models.JsonLdId { ebrains.kgcore.JSONMapper.fieldName(id,"id") }
        % empty - type: logical
        empty logical { ebrains.kgcore.JSONMapper.fieldName(empty,"empty") }
    end

    % Class methods
    methods
        % Constructor
        function obj = ResultNormalizedJsonLd_data(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.ResultNormalizedJsonLd_data
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class

