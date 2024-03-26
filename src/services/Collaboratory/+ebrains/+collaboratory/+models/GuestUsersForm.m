classdef GuestUsersForm < ebrains.collaboratory.JSONMapper
% GuestUsersForm No description provided
% 
% GuestUsersForm Properties:
%   users - type: array of GuestUser
%   expirationDate - type: datetime

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % users - type: array of GuestUser
        users ebrains.collaboratory.models.GuestUser { ebrains.collaboratory.JSONMapper.fieldName(users,"users"), ebrains.collaboratory.JSONMapper.JSONArray }
        % expirationDate - type: datetime
        expirationDate datetime { ebrains.collaboratory.JSONMapper.stringDatetime(expirationDate,'yyyy-MM-dd''T''HH:mm:ss.SSSZ', 'TimeZone', 'local'), ebrains.collaboratory.JSONMapper.fieldName(expirationDate,"expirationDate") }
    end

    % Class methods
    methods
        % Constructor
        function obj = GuestUsersForm(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.GuestUsersForm
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class
