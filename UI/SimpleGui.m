classdef SimpleGui
    %SIMPLEGUI Shows the sensor data and labels in a table
    
    properties
        sensorlabel = ['Sensor1';'Sensor2'];
        sensortype = ['Encoder'; '   Goat'];
        sensordata = [0,0];
    end
    
    methods(Static)
    end
    
    methods 
        function gui = SimpleGui(input)
            if(nargin >0)
                gui.sensorlabel = input{1,1};
                gui.sensortype = input{1,2};                
                gui.sensordata = input{1,3};
                f = figure('Position', [100 100 752 250]);
                t = uitable('Parent', f, 'Position', [25 50 700 200], 'Data',input)
            end
        end
        
    end
end

