classdef KGServer
    enumeration
        PROD("prod")
        PREPROD("preprod")
    end
    properties
        Name
    end
    methods
        function obj = KGServer(name)
            obj.Name = name;
        end
    end
end
