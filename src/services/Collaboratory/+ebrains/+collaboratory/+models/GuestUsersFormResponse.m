classdef GuestUsersFormResponse < ebrains.collaboratory.JSONMapper
% GuestUsersFormResponse No description provided
% 
% GuestUsersFormResponse Properties:
%   usersCreated - type: array of CollabUser
%   usersInError - type: array of UserErrorResponse

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % usersCreated - type: array of CollabUser
        usersCreated ebrains.collaboratory.models.CollabUser { ebrains.collaboratory.JSONMapper.fieldName(usersCreated,"usersCreated"), ebrains.collaboratory.JSONMapper.JSONArray }
        % usersInError - type: array of UserErrorResponse
        usersInError ebrains.collaboratory.models.UserErrorResponse { ebrains.collaboratory.JSONMapper.fieldName(usersInError,"usersInError"), ebrains.collaboratory.JSONMapper.JSONArray }
    end

    % Class methods
    methods
        % Constructor
        function obj = GuestUsersFormResponse(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.GuestUsersFormResponse
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class

