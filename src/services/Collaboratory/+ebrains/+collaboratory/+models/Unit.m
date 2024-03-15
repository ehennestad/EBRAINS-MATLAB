classdef Unit < ebrains.collaboratory.JSONMapper
% Unit No description provided
% 
% Unit Properties:
%   id - type: string
%   title - type: string
%   name - type: string
%   description - type: string
%   acceptMembershipRequest - type: logical

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % id - type: string
        id string { ebrains.collaboratory.JSONMapper.fieldName(id,"id") }
        % title - type: string
        title string { ebrains.collaboratory.JSONMapper.fieldName(title,"title") }
        % name - type: string
        name string { ebrains.collaboratory.JSONMapper.fieldName(name,"name") }
        % description - type: string
        description string { ebrains.collaboratory.JSONMapper.fieldName(description,"description") }
        % acceptMembershipRequest - type: logical
        acceptMembershipRequest logical { ebrains.collaboratory.JSONMapper.fieldName(acceptMembershipRequest,"acceptMembershipRequest") }
    end

    % Class methods
    methods
        % Constructor
        function obj = Unit(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.Unit
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class

