classdef FreeFormObject < dynamicprops
    % Class methods

    

    methods
        function obj = FreeFormObject(json)
            if nargin==0
                return
            end
            if isstruct(json)
                % When called recursively
                s = json;
            else
                % When called with original JSON as input
                s = jsondecode(json);
            end
            % For all the fields in the struct
            for f = string(fieldnames(s))'
                % Add a dynamic property
                obj.addprop(f);
                if isstruct(s.(f))
                    % If the field is another struct, call the method
                    % recursively such that the property also becomes another
                    % FreeFromObject
                    obj.(f) = ebrains.dataproxy.models.FreeFormObject(s.(f));
                else
                    % Any other type just assign to the field
                    obj.(f) = s.(f);
                end
            end
        end
    end %methods
end

