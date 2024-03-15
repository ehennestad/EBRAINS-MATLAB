classdef JsonLdId < ebrains.kgcore.JSONMapper
% JsonLdId No description provided
% 
% JsonLdId Properties:
%   id - type: string

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % id - type: string
        id string { ebrains.kgcore.JSONMapper.fieldName(id,"@id") }
    end

    % Class methods
    methods
        % Constructor
        function obj = JsonLdId(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.JsonLdId
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class

