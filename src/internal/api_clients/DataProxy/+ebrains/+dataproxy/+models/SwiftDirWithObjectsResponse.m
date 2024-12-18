classdef SwiftDirWithObjectsResponse < ebrains.dataproxy.JSONMapper
% SwiftDirWithObjectsResponse No description provided
% 
% SwiftDirWithObjectsResponse Properties:
%   subdir - type: string
%   bytes - type: int32
%   last_modified - type: string
%   objects_count - type: int32

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % subdir - type: string
        subdir string { ebrains.dataproxy.JSONMapper.fieldName(subdir,"subdir") }
        % bytes - type: int32
        bytes int32 { ebrains.dataproxy.JSONMapper.fieldName(bytes,"bytes") }
        % last_modified - type: string
        last_modified string { ebrains.dataproxy.JSONMapper.fieldName(last_modified,"last_modified") }
        % objects_count - type: int32
        objects_count int32 { ebrains.dataproxy.JSONMapper.fieldName(objects_count,"objects_count") }
    end

    % Class methods
    methods
        % Constructor
        function obj = SwiftDirWithObjectsResponse(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.dataproxy.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.dataproxy.models.SwiftDirWithObjectsResponse
            end
            obj@ebrains.dataproxy.JSONMapper(s,inputs);
        end
    end %methods
end %class

