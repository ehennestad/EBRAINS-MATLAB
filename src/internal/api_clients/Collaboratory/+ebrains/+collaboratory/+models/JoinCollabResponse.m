classdef JoinCollabResponse < ebrains.collaboratory.JSONMapper
% JoinCollabResponse No description provided
% 
% JoinCollabResponse Properties:
%   collabId - type: string
%   role - type: string

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % collabId - type: string
        collabId string { ebrains.collaboratory.JSONMapper.fieldName(collabId,"collabId") }
        % role - type: string
        role string { ebrains.collaboratory.JSONMapper.fieldName(role,"role") }
    end

    % Class methods
    methods
        % Constructor
        function obj = JoinCollabResponse(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.JoinCollabResponse
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class

