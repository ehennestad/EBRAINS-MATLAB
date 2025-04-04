classdef ScopeElement < ebrains.kgcore.JSONMapper
% ScopeElement No description provided
% 
% ScopeElement Properties:
%   id - type: string
%   label - type: string
%   space - type: string
%   internalId - type: string
%   types - type: array of string
%   children - type: array of ScopeElement
%   permissions - type: array of string

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % id - type: string
        id string { ebrains.kgcore.JSONMapper.fieldName(id,"id") }
        % label - type: string
        label string { ebrains.kgcore.JSONMapper.fieldName(label,"label") }
        % space - type: string
        space string { ebrains.kgcore.JSONMapper.fieldName(space,"space") }
        % internalId - type: string
        internalId string { ebrains.kgcore.JSONMapper.fieldName(internalId,"internalId") }
        % types - type: array of string
        types string { ebrains.kgcore.JSONMapper.fieldName(types,"types"), ebrains.kgcore.JSONMapper.JSONArray }
        % children - type: array of ScopeElement
        children ebrains.kgcore.models.ScopeElement { ebrains.kgcore.JSONMapper.fieldName(children,"children"), ebrains.kgcore.JSONMapper.JSONArray }
        % permissions - type: array of string
        permissions string { ebrains.kgcore.JSONMapper.fieldName(permissions,"permissions"), ebrains.kgcore.JSONMapper.JSONArray }
    end

    % Class methods
    methods
        % Constructor
        function obj = ScopeElement(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.ScopeElement
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class

