classdef UserErrorResponse < ebrains.collaboratory.JSONMapper
% UserErrorResponse No description provided
% 
% UserErrorResponse Properties:
%   user - type: CollabUser
%   fieldInError - type: string
%   fieldInErrorValue - type: string
%   userEmail - type: string
%   message - type: string

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % user - type: CollabUser
        user ebrains.collaboratory.models.CollabUser { ebrains.collaboratory.JSONMapper.fieldName(user,"user") }
        % fieldInError - type: string
        fieldInError string { ebrains.collaboratory.JSONMapper.fieldName(fieldInError,"fieldInError") }
        % fieldInErrorValue - type: string
        fieldInErrorValue string { ebrains.collaboratory.JSONMapper.fieldName(fieldInErrorValue,"fieldInErrorValue") }
        % userEmail - type: string
        userEmail string { ebrains.collaboratory.JSONMapper.fieldName(userEmail,"userEmail") }
        % message - type: string
        message string { ebrains.collaboratory.JSONMapper.fieldName(message,"message") }
    end

    % Class methods
    methods
        % Constructor
        function obj = UserErrorResponse(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.UserErrorResponse
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class
