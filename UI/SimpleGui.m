classdef SimpleGui <handle 
    %SIMPLEGUI Shows the sensor data and labels in a table
    
    properties
        data = {};
        sensorlabel = {};
        sensortype = {};
        importantSensors = [];
        
        SIPreFixes = {'G'    'M'    'k'    'h'    'da'  'none'  'd'    'c'    'm'    'µ'    'n'}; 
        SItrans = {@(x)x*10^9    @(x)x*10^6    @(x)x*10^3    ...
            @(x)x*10^2    @(x)x*10^1    @(x)x*10^0    @(x)x*10^-1    @(x)x*10^-2    @(x)x*10^-3 ...
            @(x)x*10^-6    @(x)x*10^-9}
        
        impSensors;
        allSensors;
        convTable;
        
        graph;
        graph2;
        
        ddg1;
        ddg2;
        root;
        
        
        updateFlag = true;
        updateRate = 0.02;
        
        graphSensors =[1 2];
        databacklog;
    end
    
    methods(Static)
        %test function which emulates having a continuous stream of data
        function streamTest
            data = SensorDataContainer(SensorDataContainer.convertSignalData(importdata('TestData2.mat'),6));
            gui= SimpleGui(data,[1:13]);
            updateCheck = uicontrol('Style','checkbox','Callback',@updateC,'Position',[0,750,25,25]);

            function updateC(hObject, eventdata, handles)
                gui.updateFlag = get(hObject,'Value') == get(hObject,'Max');
                while gui.updateFlag;
                    rndVals = cellfun(@(x) x*(rand(1)+0.5),data.returnColumn(3),'un',0);
                    data.setColumn(3,transpose(rndVals));
                    gui.update(data);
                    pause(gui.updateRate);
                end
            end
        end
    end
    
    methods 
        function gui = SimpleGui(sensorData, importantSensors)
            close all;
            if(nargin >0)
                 gui.data=sensorData;
                 gui.sensorlabel = sensorData.returnColumn(1);
                 gui.sensortype = sensorData.returnColumn(2);
                 gui.importantSensors = importantSensors;
                 
                gui.root = figure('Position', [100 100 1600 800], 'MenuBar', 'None');
                divParams =[
                    gui.root.Position(1)+(gui.root.Position(3)*0.8)
                    gui.root.Position(2)+(gui.root.Position(4)*0.5)
                    gui.root.Position(3)*0.8
                    gui.root.Position(4)*0.5
                    gui.root.Position(3)*0.2
                    gui.root.Position(4)
                ];
             
                naxes = 2;
                gui.databacklog = transpose(sensorData.returnColumn([1,3]));                
                gui.generateGraphs(naxes,divParams);
                gui.generateTables(divParams);            
            end
        end
        
       %creates tables
        function generateTables(gui,divParams)
             gui.impSensors = uitable('Parent', gui.root,... 
                'Position', [25 divParams(4)+25 divParams(3) divParams(4)],... 
                'Data',gui.data.datamatrix(gui.importantSensors,:),...
                'BackgroundColor', [0.9 0.9 1 ;0.5 0.5 1],'FontSize', 14,...
                'ColumnWidth', {150,250,'auto','auto','auto','auto'},...
                'RowName',[],'ColumnName',[]...
              );
            
                gui.convTable = uitable('Parent', gui.root,... 
                    'Data', transpose(gui.SIPreFixes)...
                    ,'BackgroundColor', [0.9 0.9 1 ;0.5 0.5 1],'FontSize', 14,...
                    'ColumnWidth', {150,250,'auto','auto','auto','auto'},...
                    'RowName',[],'ColumnName',[]...
                );
            
                gui.impSensors.Position(3) = gui.impSensors.Extent(3);
                gui.impSensors.Position(4) = gui.impSensors.Extent(4);
                
                gui.convTable.Position(1) =gui.impSensors.Position(1) +gui.impSensors.Position(3);
                gui.convTable.Position(2) = gui.impSensors.Position(2);

                gui.allSensors = uitable('Parent', gui.root, 'Position', [divParams(3)+25 0 divParams(5) divParams(6) ],...
                    'Data',gui.data.datamatrix(:,1:3),'RowName',[],'ColumnName',[],...
                    'ColumnWidth', {100,150,30}, 'Visible','off'...
                );    
            
                gui.allSensors.Position(3) = gui.allSensors.Extent(3)+20;               
                showAll = uicontrol('Style','checkbox','Callback',@toggleAll,'Position',[divParams(3) divParams(6)-25 25 25]);
                
                function toggleAll(hObject,eventData)
                   if(get(hObject,'Value') == get(hObject,'Max'))
                       gui.allSensors.Visible = 'on';
                   else
                       gui.allSensors.Visible = 'off';
                   end
                end
       end
        
       %creates the graphs
       function generateGraphs(gui, naxes,divParams)
            gui.ddg1 = uicontrol('Style', 'popup',...
                'String', gui.sensorlabel,...
                'Position', [25 370 100 50]...
            );   
            gui.ddg2 = uicontrol('Style', 'popup',...
                'String', gui.sensorlabel,'Value',2,...
                'Position', [665 370 100 50]...
            );                  
            gui.graph = axes('Units','pixels', 'Position', [25,25,(divParams(3)/naxes)-25,divParams(4)-25]);
            gui.graph.Units = 'normalized';
            gui.graph.Title.String = gui.data.returnEntry(gui.graphSensors(1),1);
            gui.graph2 = axes('Units','pixels', 'Position', [25+(divParams(3)/naxes),25,(divParams(3)/naxes)-25,divParams(4)-25] );
            gui.graph2.Units = 'normalized';
            gui.graph2.Title.String = gui.data.returnEntry(gui.graphSensors(2),1);
        end        
        
        %updates the sensor tables in the GUI
        function update(gui,data)   
            gui.graphSensors(1)=gui.ddg1.Value;
            gui.graphSensors(2)=gui.ddg2.Value;

            
            gui.impSensors.Data = data.datamatrix(gui.importantSensors,:);
            gui.allSensors.Data = data.datamatrix;
            
            gui.databacklog = vertcat(gui.databacklog,transpose(data.returnColumn(3)));
            axes(gui.graph2);
            plot(cell2mat(transpose(gui.databacklog(max(2,end-20):end,gui.graphSensors(2)))));
            gui.graph2.Title.String = data.returnEntry(gui.graphSensors(2),1);
            
            axes(gui.graph);
            plot(cell2mat(transpose(gui.databacklog(max(2,end-20):end,gui.graphSensors(1)))));
            gui.graph.Title.String = data.returnEntry(gui.graphSensors(1),1);
            drawnow;
        end        
    end
end

