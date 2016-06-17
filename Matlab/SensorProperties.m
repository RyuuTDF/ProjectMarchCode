classdef SensorProperties
    % SENSORPROPERTIES contains the properties of a given sensor
    
    properties
        label = '';
        type = '';
        siUnit = '';
        siOrgPrefix = 'none';
        siCurrPrefix = 'none';
        transformation;
        minVal;
        maxVal;
    end
    
    methods
        % Function: SensorProperties
        % Functionality: Constructor
        function sensor = SensorProperties(label, type,min,max)
            if(nargin >0)
                sensor.label = label;
                sensor.type = type;        
                sensor.transformation = @(x)x;
                if(nargin >2)
                    sensor.minVal = min;
                    sensor.maxVal = max;
                end
            end
        end
    end
end

