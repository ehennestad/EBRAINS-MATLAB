classdef BucketListEntry < ebrains.dataproxy.JSONMapper
% BucketListEntry No description provided
% 
% BucketListEntry Properties:
%   name - type: string
%   role - type: UserRole
%   is_public - type: logical

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % name - type: string
        name string { ebrains.dataproxy.JSONMapper.fieldName(name,"name") }
        % role - type: UserRole
        role  { ebrains.dataproxy.JSONMapper.fieldName(role,"role") }
        % is_public - type: logical
        is_public logical { ebrains.dataproxy.JSONMapper.fieldName(is_public,"is_public") }
    end

    % Class methods
    methods
        % Constructor
        function obj = BucketListEntry(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.dataproxy.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.dataproxy.models.BucketListEntry
            end
            obj@ebrains.dataproxy.JSONMapper(s,inputs);
        end
    end %methods
end %class

