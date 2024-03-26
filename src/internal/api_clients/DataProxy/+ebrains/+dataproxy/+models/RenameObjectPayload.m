classdef RenameObjectPayload < ebrains.dataproxy.JSONMapper
% RenameObjectPayload No description provided
% 
% RenameObjectPayload Properties:
%   rename - type: RenameObjectSetting

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % rename - type: RenameObjectSetting
        rename ebrains.dataproxy.models.RenameObjectSetting { ebrains.dataproxy.JSONMapper.fieldName(rename,"rename") }
    end

    % Class methods
    methods
        % Constructor
        function obj = RenameObjectPayload(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.dataproxy.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.dataproxy.models.RenameObjectPayload
            end
            obj@ebrains.dataproxy.JSONMapper(s,inputs);
        end
    end %methods
end %class
