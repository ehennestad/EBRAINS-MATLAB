classdef ClientRepresentation < ebrains.collaboratory.JSONMapper
% ClientRepresentation No description provided
% 
% ClientRepresentation Properties:
%   id - type: string
%   clientId - type: string
%   name - type: string
%   description - type: string
%   rootUrl - type: string
%   adminUrl - type: string
%   baseUrl - type: string
%   surrogateAuthRequired - type: logical
%   enabled - type: logical
%   alwaysDisplayInConsole - type: logical
%   clientAuthenticatorType - type: string
%   secret - type: string
%   registrationAccessToken - type: string
%   redirectUris - type: array of string
%   webOrigins - type: array of string
%   bearerOnly - type: logical
%   consentRequired - type: logical
%   standardFlowEnabled - type: logical
%   implicitFlowEnabled - type: logical
%   directAccessGrantsEnabled - type: logical
%   serviceAccountsEnabled - type: logical
%   authorizationServicesEnabled - type: logical
%   publicClient - type: logical
%   frontchannelLogout - type: logical
%   protocol - type: string
%   attributes - type: ebrains.collaboratory.JSONMapperMap
%   authenticationFlowBindingOverrides - type: ebrains.collaboratory.JSONMapperMap
%   fullScopeAllowed - type: logical
%   nodeReRegistrationTimeout - type: int32
%   registeredNodes - type: ebrains.collaboratory.JSONMapperMap
%   defaultClientScopes - type: array of string
%   optionalClientScopes - type: array of string
%   access - type: ebrains.collaboratory.JSONMapperMap
%   origin - type: string

% This file is automatically generated using OpenAPI
% Specification version: 1.0
% MATLAB Generator for OpenAPI version: 1.0.9


    % Class properties
    properties
        % id - type: string
        id string { ebrains.collaboratory.JSONMapper.fieldName(id,"id") }
        % clientId - type: string
        clientId string { ebrains.collaboratory.JSONMapper.fieldName(clientId,"clientId") }
        % name - type: string
        name string { ebrains.collaboratory.JSONMapper.fieldName(name,"name") }
        % description - type: string
        description string { ebrains.collaboratory.JSONMapper.fieldName(description,"description") }
        % rootUrl - type: string
        rootUrl string { ebrains.collaboratory.JSONMapper.fieldName(rootUrl,"rootUrl") }
        % adminUrl - type: string
        adminUrl string { ebrains.collaboratory.JSONMapper.fieldName(adminUrl,"adminUrl") }
        % baseUrl - type: string
        baseUrl string { ebrains.collaboratory.JSONMapper.fieldName(baseUrl,"baseUrl") }
        % surrogateAuthRequired - type: logical
        surrogateAuthRequired logical { ebrains.collaboratory.JSONMapper.fieldName(surrogateAuthRequired,"surrogateAuthRequired") }
        % enabled - type: logical
        enabled logical { ebrains.collaboratory.JSONMapper.fieldName(enabled,"enabled") }
        % alwaysDisplayInConsole - type: logical
        alwaysDisplayInConsole logical { ebrains.collaboratory.JSONMapper.fieldName(alwaysDisplayInConsole,"alwaysDisplayInConsole") }
        % clientAuthenticatorType - type: string
        clientAuthenticatorType string { ebrains.collaboratory.JSONMapper.fieldName(clientAuthenticatorType,"clientAuthenticatorType") }
        % secret - type: string
        secret string { ebrains.collaboratory.JSONMapper.fieldName(secret,"secret") }
        % registrationAccessToken - type: string
        registrationAccessToken string { ebrains.collaboratory.JSONMapper.fieldName(registrationAccessToken,"registrationAccessToken") }
        % redirectUris - type: array of string
        redirectUris string { ebrains.collaboratory.JSONMapper.fieldName(redirectUris,"redirectUris"), ebrains.collaboratory.JSONMapper.JSONArray }
        % webOrigins - type: array of string
        webOrigins string { ebrains.collaboratory.JSONMapper.fieldName(webOrigins,"webOrigins"), ebrains.collaboratory.JSONMapper.JSONArray }
        % bearerOnly - type: logical
        bearerOnly logical { ebrains.collaboratory.JSONMapper.fieldName(bearerOnly,"bearerOnly") }
        % consentRequired - type: logical
        consentRequired logical { ebrains.collaboratory.JSONMapper.fieldName(consentRequired,"consentRequired") }
        % standardFlowEnabled - type: logical
        standardFlowEnabled logical { ebrains.collaboratory.JSONMapper.fieldName(standardFlowEnabled,"standardFlowEnabled") }
        % implicitFlowEnabled - type: logical
        implicitFlowEnabled logical { ebrains.collaboratory.JSONMapper.fieldName(implicitFlowEnabled,"implicitFlowEnabled") }
        % directAccessGrantsEnabled - type: logical
        directAccessGrantsEnabled logical { ebrains.collaboratory.JSONMapper.fieldName(directAccessGrantsEnabled,"directAccessGrantsEnabled") }
        % serviceAccountsEnabled - type: logical
        serviceAccountsEnabled logical { ebrains.collaboratory.JSONMapper.fieldName(serviceAccountsEnabled,"serviceAccountsEnabled") }
        % authorizationServicesEnabled - type: logical
        authorizationServicesEnabled logical { ebrains.collaboratory.JSONMapper.fieldName(authorizationServicesEnabled,"authorizationServicesEnabled") }
        % publicClient - type: logical
        publicClient logical { ebrains.collaboratory.JSONMapper.fieldName(publicClient,"publicClient") }
        % frontchannelLogout - type: logical
        frontchannelLogout logical { ebrains.collaboratory.JSONMapper.fieldName(frontchannelLogout,"frontchannelLogout") }
        % protocol - type: string
        protocol string { ebrains.collaboratory.JSONMapper.fieldName(protocol,"protocol") }
        % attributes - type: ebrains.collaboratory.JSONMapperMap
        attributes ebrains.collaboratory.JSONMapperMap { ebrains.collaboratory.JSONMapper.fieldName(attributes,"attributes") }
        % authenticationFlowBindingOverrides - type: ebrains.collaboratory.JSONMapperMap
        authenticationFlowBindingOverrides ebrains.collaboratory.JSONMapperMap { ebrains.collaboratory.JSONMapper.fieldName(authenticationFlowBindingOverrides,"authenticationFlowBindingOverrides") }
        % fullScopeAllowed - type: logical
        fullScopeAllowed logical { ebrains.collaboratory.JSONMapper.fieldName(fullScopeAllowed,"fullScopeAllowed") }
        % nodeReRegistrationTimeout - type: int32
        nodeReRegistrationTimeout int32 { ebrains.collaboratory.JSONMapper.fieldName(nodeReRegistrationTimeout,"nodeReRegistrationTimeout") }
        % registeredNodes - type: ebrains.collaboratory.JSONMapperMap
        registeredNodes ebrains.collaboratory.JSONMapperMap { ebrains.collaboratory.JSONMapper.fieldName(registeredNodes,"registeredNodes") }
        % defaultClientScopes - type: array of string
        defaultClientScopes string { ebrains.collaboratory.JSONMapper.fieldName(defaultClientScopes,"defaultClientScopes"), ebrains.collaboratory.JSONMapper.JSONArray }
        % optionalClientScopes - type: array of string
        optionalClientScopes string { ebrains.collaboratory.JSONMapper.fieldName(optionalClientScopes,"optionalClientScopes"), ebrains.collaboratory.JSONMapper.JSONArray }
        % access - type: ebrains.collaboratory.JSONMapperMap
        access ebrains.collaboratory.JSONMapperMap { ebrains.collaboratory.JSONMapper.fieldName(access,"access") }
        % origin - type: string
        origin string { ebrains.collaboratory.JSONMapper.fieldName(origin,"origin") }
    end

    % Class methods
    methods
        % Constructor
        function obj = ClientRepresentation(s,inputs)
            % To allow proper nesting of object, derived objects must
            % call the JSONMapper constructor from their constructor. This 
            % also allows objects to be instantiated with Name-Value pairs
            % as inputs to set properties to specified values.
            arguments
                s { ebrains.collaboratory.JSONMapper.ConstructorArgument } = []
                inputs.?ebrains.collaboratory.models.ClientRepresentation
            end
            obj@ebrains.collaboratory.JSONMapper(s,inputs);
        end
    end %methods
end %class

