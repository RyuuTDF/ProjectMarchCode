classdef SimpleGui <handle 
    %SIMPLEGUI Shows the sensor data and labels in a table
    
    properties
        sensorlabel = {};
        sensortype = {};
        importantSensors = [];
        impSensors;
        allSensors;
        graph;
        graph2;
    end
    
    methods(Static)
        function streamTest
            data = SensorDataContainer(importdata('TestData.mat'));
            gui= SimpleGui(data,[1,3]);
            databacklog = transpose(data.returnColumn([1,3]))
            while true
                rndVals = cellfun(@(x) x*(rand(1)+0.5),data.returnColumn(3),'un',0);
                data.setColumn(3,transpose(rndVals));
                gui.update(data);
                databacklog = vertcat(databacklog,transpose(data.returnColumn(3)));
                axes(gui.graph2);
                plot(cell2mat(transpose(databacklog(2:end,1))));
                axes(gui.graph);
                plot(cell2mat(transpose(databacklog(2:end,2))));
                pause(0.02);
            end
        end
    end
    
    methods 
        function gui = SimpleGui(sensorData, importantSensors)
            close all;
            if(nargin >0)
                 gui.sensorlabel = sensorData.returnColumn(1);
                 gui.sensortype = sensorData.returnColumn(2);
                 gui.importantSensors = importantSensors;
                 
                rootFig = figure('Position', [100 100 800 800]);
                gui.graph = axes('Units','pixels','Position',[25,25,300,300]);
                gui.graph.Units = 'normalized';
                gui.graph2 = axes('Units','pixels','Position',[375,25,300,300]);
                gui.graph2.Units = 'normalized';
                
                gui.impSensors = uitable('Parent', rootFig, 'Position', [0 350 300 250], 'Data',sensorData.datamatrix(importantSensors,:),'RowName',[],'ColumnName',[]);                
                gui.allSensors = uitable('Parent', rootFig, 'Position', [250 350 300 250], 'Data',sensorData.datamatrix,'RowName',[],'ColumnName',[]);            
            end
        end
        function update(gui,data)
            gui.impSensors.Data = data.datamatrix(gui.importantSensors,:);
            gui.allSensors.Data = data.datamatrix;
        end
        
    end
end

