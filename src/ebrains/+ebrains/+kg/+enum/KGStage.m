classdef KGStage
    %KGStage - Stages of the Knowledge Graph an instance can be read from
    %   KGStage enumerates the two stages of the EBRAINS Knowledge Graph
    %   (KG). An instance is edited in progress and becomes public once it
    %   is released. The KG API clients accept a member, or its name as
    %   text, in their stage arguments.
    %
    %   KGStage members:
    %       RELEASED    - Released instances, visible to everyone
    %       IN_PROGRESS - Instances under edit, visible to those with access
    %                     to their space
    %
    %   KGStage properties:
    %       Name - Human-readable name of the stage
    %
    %   See also ebrains.kg.api.InstancesClient

    enumeration
        RELEASED("released")
        IN_PROGRESS("in progress")
    end

    properties
        Name  % Human-readable name of the stage
    end
    methods
        function obj = KGStage(name)
            obj.Name = name;
        end
    end
end
