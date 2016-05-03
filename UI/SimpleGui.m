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
        graphSensors =[3 2];
        databacklog;
    end
    
    methods(Static)
        %test function which emulates having a continuous stream of data
        function streamTest
            data = SensorDataContainer(SensorDataContainer.convertSignalData(importdata('TestData2.mat'),6));
            gui= SimpleGui(data,[1:13]);
            while true
                rndVals = cellfun(@(x) x*(rand(1)+0.5),data.returnColumn(3),'un',0);
                data.setColumn(3,transpose(rndVals));
                gui.update(data);
                pause(0.5);
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
                 
                rootFig = figure('Position', [100 100 1600 800], 'MenuBar', 'None');
                divParams =[
                    rootFig.Position(1)+(rootFig.Position(3)*0.8)
                    rootFig.Position(2)+(rootFig.Position(4)*0.5)
                    rootFig.Position(3)*0.8
                    rootFig.Position(4)*0.5
                    rootFig.Position(3)*0.2
                    rootFig.Position(4)
                ];
            
                popup = uicontrol('Style', 'popup',...
                'String', gui.sensorlabel,...
                'Position', [20 340 100 50],...
                'Callback', @changeGraph);   
                naxes = 2;
                gui.databacklog = transpose(sensorData.returnColumn([1,3]));

                
                gui.graph = axes('Units','pixels', 'Position', [25,25,(divParams(3)/naxes)-25,divParams(4)-25]);
                gui.graph.Units = 'normalized';
                gui.graph.Title.String = sensorData.returnEntry(gui.graphSensors(1),1);
                gui.graph2 = axes('Units','pixels', 'Position', [25+(divParams(3)/naxes),25,(divParams(3)/naxes)-25,divParams(4)-25] );
                gui.graph2.Units = 'normalized';
                gui.graph2.Title.String = sensorData.returnEntry(gui.graphSensors(2),1);

                                
                gui.impSensors = uitable('Parent', rootFig,... 
                'Position', [250 divParams(4)+25 divParams(3) divParams(4)],... 
                'Data',sensorData.datamatrix(importantSensors,:),...
                'BackgroundColor', [0.9 0.9 1 ;0.5 0.5 1],'FontSize', 14,...
                'ColumnWidth', {150,250,'auto','auto','auto','auto'},...
                'RowName',[],'ColumnName',[]...
                );
                gui.impSensors.Position(3) = gui.impSensors.Extent(3);
                gui.impSensors.Position(4) = gui.impSensors.Extent(4);
                gui.allSensors = uitable('Parent', rootFig, 'Position', [divParams(3)+25 0 divParams(5) divParams(6) ],...
                    'Data',sensorData.datamatrix(:,1:3),'RowName',[],'ColumnName',[],...
                    'ColumnWidth', {100,150,30}...
                );
                gui.allSensors.Position(3) = gui.allSensors.Extent(3)+20;
                
 
            

            end
            function changeGraph(source, callbackdata)
                val = source.Value;
                graph = source.String;               
                gui.graphSensors(1)=val;
                drawnow();
            end
        end
        %updates the sensor tables in the GUI
        function update(gui,data)   
            gui.impSensors.Data = data.datamatrix(gui.importantSensors,:);
            gui.allSensors.Data = data.datamatrix;
            
            gui.databacklog = vertcat(gui.databacklog,transpose(data.returnColumn(3)));
            axes(gui.graph2);
            plot(cell2mat(transpose(gui.databacklog(max(2,end-20):end,gui.graphSensors(2)))));
            gui.graph2.Title.String = data.returnEntry(gui.graphSensors(2),1);
            
            axes(gui.graph);
            plot(cell2mat(transpose(gui.databacklog(max(2,end-20):end,gui.graphSensors(1)))));
            gui.graph.Title.String = data.returnEntry(gui.graphSensors(1),1);
            
        end
        
    end
end

