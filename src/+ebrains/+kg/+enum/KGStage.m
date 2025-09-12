classdef KGStage
    enumeration
        RELEASED("released")
        IN_PROGRESS("in progress")
        ANY("any")
    end
    properties
        Name
    end
    methods
        function obj = KGStage(name)
            obj.Name = name;
        end
    end
end
