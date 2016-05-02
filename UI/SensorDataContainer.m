classdef SensorDataContainer
    %SENSORDATACONTAINER Contains the sensor data and methods to convert
    %the data to certain formats
    
    properties
        datamatrix = {};
    end
    
    methods(Static)
        
    end
    
    methods
        function matrix = SensorDataContainer(input)
            matrix.datamatrix = input;          
        end
    end
    
end

