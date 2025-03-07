classdef SuggestionResult < ebrains.kgcore.JSONMapper
% SuggestionResult No description provided
% 
% SuggestionResult Properties:
%   suggestions - type: PaginatedSuggestedLink
%   types - type: ebrains.kgcore.JSONMapperMap

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % suggestions - type: PaginatedSuggestedLink
        suggestions ebrains.kgcore.models.PaginatedSuggestedLink { ebrains.kgcore.JSONMapper.fieldName(suggestions,"suggestions") }
        % types - type: ebrains.kgcore.JSONMapperMap
        types  { ebrains.kgcore.JSONMapper.fieldName(types,"types") }
    end

    % Class methods
    methods
        % Constructor
        function obj = SuggestionResult(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.SuggestionResult
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class

