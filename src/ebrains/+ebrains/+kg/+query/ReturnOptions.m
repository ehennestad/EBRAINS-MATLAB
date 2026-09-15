classdef ReturnOptions < handle
    %ReturnOptions - Name-value options shared by the KG instance methods
    %   ReturnOptions declares the return options that the methods of
    %   InstancesClient accept through their arguments blocks. Each option
    %   tells the KG server which parts of an instance to include in the
    %   response. The class is not meant to be created directly.
    %
    %   ReturnOptions properties:
    %       returnPayload      - Whether to include the instance properties
    %       returnPermissions  - Whether to include the permissions of the
    %                            user on the instance
    %       returnAlternatives - Whether to include alternative values of
    %                            the properties
    %       returnEmbedded     - Whether to include embedded instances
    %
    %   See also ebrains.kg.api.InstancesClient

    properties
        returnPayload          logical  % Whether to include the instance properties
        returnPermissions      logical  % Whether to include the permissions of the user
        returnAlternatives     logical  % Whether to include alternative property values
        returnEmbedded         logical  % Whether to include embedded instances
    end
end
