classdef UserWithRoles < ebrains.kgcore.JSONMapper
% UserWithRoles No description provided
% 
% UserWithRoles Properties:
%   user - type: ResultUser_data
%   invitations - type: array of string
%   clientId - type: string
%   permissions - type: array of FunctionalityInstance
%   privateSpace - type: SpaceName

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % user - type: ResultUser_data
        user  { ebrains.kgcore.JSONMapper.fieldName(user,"user") }
        % invitations - type: array of string
        invitations string { ebrains.kgcore.JSONMapper.fieldName(invitations,"invitations"), ebrains.kgcore.JSONMapper.JSONArray }
        % clientId - type: string
        clientId string { ebrains.kgcore.JSONMapper.fieldName(clientId,"clientId") }
        % permissions - type: array of FunctionalityInstance
        permissions ebrains.kgcore.models.FunctionalityInstance { ebrains.kgcore.JSONMapper.fieldName(permissions,"permissions"), ebrains.kgcore.JSONMapper.JSONArray }
        % privateSpace - type: SpaceName
        privateSpace ebrains.kgcore.models.SpaceName { ebrains.kgcore.JSONMapper.fieldName(privateSpace,"privateSpace") }
    end

    % Class methods
    methods
        % Constructor
        function obj = UserWithRoles(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.UserWithRoles
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class

