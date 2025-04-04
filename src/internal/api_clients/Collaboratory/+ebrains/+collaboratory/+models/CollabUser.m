classdef CollabUser < ebrains.collaboratory.JSONMapper
% CollabUser No description provided
% 
% CollabUser Properties:
%   id - type: string
%   mitreId - type: string
%   username - type: string
%   firstName - type: string
%   lastName - type: string
%   biography - type: string
%   avatar - type: string
%   active - type: logical

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % id - type: string
        id string { ebrains.collaboratory.JSONMapper.fieldName(id,"id") }
        % mitreId - type: string
        mitreId string { ebrains.collaboratory.JSONMapper.fieldName(mitreId,"mitreId") }
        % username - type: string
        username string { ebrains.collaboratory.JSONMapper.fieldName(username,"username") }
        % firstName - type: string
        firstName string { ebrains.collaboratory.JSONMapper.fieldName(firstName,"firstName") }
        % lastName - type: string
        lastName string { ebrains.collaboratory.JSONMapper.fieldName(lastName,"lastName") }
        % biography - type: string
        biography string { ebrains.collaboratory.JSONMapper.fieldName(biography,"biography") }
        % avatar - type: string
        avatar string { ebrains.collaboratory.JSONMapper.fieldName(avatar,"avatar") }
        % active - type: logical
        active logical { ebrains.collaboratory.JSONMapper.fieldName(active,"active") }
    end

    % Class methods
    methods
        % Constructor
        function obj = CollabUser(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.CollabUser
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class

