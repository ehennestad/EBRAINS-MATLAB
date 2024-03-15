classdef ResultJsonLdDoc < ebrains.kgcore.JSONMapper
% ResultJsonLdDoc No description provided
% 
% ResultJsonLdDoc Properties:
%   data - type: ResultNormalizedJsonLd_data
%   message - type: string
%   error - type: Error
%   startTime - type: int64
%   durationInMs - type: int64

% This file is automatically generated using OpenAPI
% Specification version: 1.0.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % data - type: ResultNormalizedJsonLd_data
        data  { ebrains.kgcore.JSONMapper.fieldName(data,"data") }
        % message - type: string
        message string { ebrains.kgcore.JSONMapper.fieldName(message,"message") }
        % error - type: Error
        error ebrains.kgcore.models.Error { ebrains.kgcore.JSONMapper.fieldName(error,"error") }
        % startTime - type: int64
        startTime int64 { ebrains.kgcore.JSONMapper.fieldName(startTime,"startTime") }
        % durationInMs - type: int64
        durationInMs int64 { ebrains.kgcore.JSONMapper.fieldName(durationInMs,"durationInMs") }
    end

    % Class methods
    methods
        % Constructor
        function obj = ResultJsonLdDoc(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.kgcore.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.kgcore.models.ResultJsonLdDoc
            end
            obj@ebrains.kgcore.JSONMapper(s,inputs);
        end
    end %methods
end %class

