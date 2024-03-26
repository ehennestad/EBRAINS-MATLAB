classdef CreateBucketPayload < ebrains.dataproxy.JSONMapper
% CreateBucketPayload No description provided
% 
% CreateBucketPayload Properties:
%   bucket_name - type: string

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % bucket_name - type: string
        bucket_name string { ebrains.dataproxy.JSONMapper.fieldName(bucket_name,"bucket_name") }
    end

    % Class methods
    methods
        % Constructor
        function obj = CreateBucketPayload(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.dataproxy.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.dataproxy.models.CreateBucketPayload
            end
            obj@ebrains.dataproxy.JSONMapper(s,inputs);
        end
    end %methods
end %class

