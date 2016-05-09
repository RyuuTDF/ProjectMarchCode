classdef SensorProperties
    %Contains properties of given sensor
    
    properties
        label = '';
        type = '';
        siUnit = '';
        siOrgPrefix = '';
        siCurrPrefix = '';
        transformation;
    end
    
    methods
        function sensor = SensorProperties(label, type)
            if(nargin >0)
                sensor.label = label;
                sensor.type = type;        
                sensor.transformation = @(x)x;
            end
        end
        function sensor = SetBaseSI(unit, prefix)
                sensor.siUnit = unit;
                sensor.siOrgPrefix = prefix;
                sensor.siCurrPrefix = prefix;
        end
    end
end

