classdef SensorProperties
    %Contains properties of given sensor
    
    properties
        label = '';
        type = '';
        siUnit = '';
        siOrgPrefix = 'none';
        siCurrPrefix = 'none';
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
    end
end

