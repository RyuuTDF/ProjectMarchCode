classdef SimpleGui <handle
    %SIMPLEGUI Shows the sensor data and labels in a table
    properties
        config;
        env = Env();
        data = {};
        sensorLabel = {};
        sensorTabel = {};
        sensorMin = [];
        sensorMax = [];
        
        importantSensors = [];
        tableSize = 9;
        sensorTranforms;
        impSensCheck;
        
        sensorProperties;
        selectedSensor;
        
        siPrefixes = {'G'    'M'    'k'    'h'    'da'  'none'  'd'    'c'    'm'    'µ'    'n'};
        siTransformations = {@(x)x*10^9    @(x)x*10^6    @(x)x*10^3    ...
            @(x)x*10^2    @(x)x*10^1    @(x)x*10^0    @(x)x*10^-1    @(x)x*10^-2    @(x)x*10^-3 ...
            @(x)x*10^-6    @(x)x*10^-9};
        
        impSensorsLabel;
        impSensorsData;
        allSensors;
        convTable;
        propTable;
        
        graph;
        graph2;      
        ddg1;
        ddg2;
        root;
        
        
        updateFlag = true;
        updateRate;
        
        graphSensors =[1 2];
        databacklog;
        dataSlidingWindow;
        backlogPointer;
        backlogSize;
    end
    
    methods(Static)
        %test function which emulates having a continuous stream of data
        function gui = streamTest
            
            config = importdata('GuiConfig.mat');
            config = SimpleGui.resize(config);
            %Sets up the environment
            if(strcmp(config.env,'local'))
                env = LocalEnv(config.src);
            else
                env = NetworkEnv();
            end

            
            gui= SimpleGui(env.currentdata,config);
            updateCheck = uicontrol('Style','checkbox','Callback',@updateC,...
                'Position',[0,750,25,25]);
            gui.updateRate = config.updateFreq;
            %callback function for the update checkbox; only updates data when
            %the checkbox is marked
            function updateC(hObject, eventdata, handles)
                gui.updateFlag = get(hObject,'Value') == get(hObject,'Max');
                allCnt =0;
                allUpdate= config.allUpdateRate/config.updateFreq;
                while gui.updateFlag;
                    allCnt = allCnt+1;
                    env = updateData(env);
                    gui.update(env.currentdata, mod(allCnt,allUpdate) ==0);

                    pause(gui.updateRate);
                end
            end
        end
        
        %generates a uitable with 'data' with the same properties as the
        %parenttable and has the rightbottom corner of the parenttable as
        %leftbottom corner
        function newTable = concatUItab(baseTable,data)
            newTable = uitable();
            newTable.Data = data;
            
            newTable.Position(1) = baseTable.Position(1)+baseTable.Extent(3);
            newTable.Position(2) = baseTable.Position(2);
            newTable.Position(3) = newTable.Extent(3);
            newTable.Position(4) = baseTable.Extent(4);
            
            newTable.BackgroundColor = baseTable.BackgroundColor;
            newTable.FontSize = baseTable.FontSize;
            newTable.ColumnName =  [];
            newTable.RowName = baseTable.RowName;
        end
        
        %changes the config file based on the size settin
        function config = resize(config)
            switch config.size
                case 's';
                    config.figPos = config.figPosS;
                    config.font = config.fontS;
                    config.impTabWidth = config.impTabWidthS;
                case 'm'
                    config.figPos=config.figPosM;
                    config.font = config.fontM;
                    config.impTabWidth = config.impTabWidthM;
            end
        end
        
        %generates html for cell coloring
        function html = colorgen(color,str)
            html = ['<html><table border=0 width=400 bgcolor=',color,...
                '><TR><TD>',str,'</TD></TR> </table></html>'];
        end
        
    end
    
    methods
        %constructor function for the gui
        function gui = SimpleGui(sensorData, config)
            gui.config = config;
            importantSensors = config.impSens;
            %removes all open figures for a clean slate
            close all;
            if(nargin >0)
                %sets the data properties
                gui.data=sensorData;
                gui.sensorLabel = sensorData.returnColumn(1);
                gui.sensorTabel = sensorData.returnColumn(2);
                gui.sensorMin = cell2mat(sensorData.returnColumn(3));
                gui.sensorMax = cell2mat(sensorData.returnColumn(4));
                gui.importantSensors = importantSensors;
                gui.sensorProperties = cell(size(gui.data.datamatrix,1),1);
                
                %calls the figure object and defines some margins
                gui.root = figure('Position',config.figPos , 'MenuBar', 'None');
                divParams =[
                    gui.root.Position(1)+(gui.root.Position(3)*0.8)
                    gui.root.Position(2)+(gui.root.Position(4)*0.5)
                    gui.root.Position(3)*0.8
                    gui.root.Position(4)*0.5
                    gui.root.Position(3)*0.2
                    gui.root.Position(4)
                    ];
                gui.sensorTranforms = {};
                
                %defines the amount of axes in the figure
                naxes = config.naxes;
                gui.backlogSize=config.backlogSize;
                %used to save the incoming data
                gui.databacklog = zeros(size(gui.data.datamatrix,1),gui.backlogSize);
                gui.dataSlidingWindow = zeros(size(gui.data.datamatrix,1),gui.backlogSize);
                gui.backlogPointer = 1;
                %generates other graphic items
                gui.generateGraphs(naxes,divParams);
                gui.generateTables(divParams);
                gui.loadProperties();
            end
        end
        
        %creates tables
        function generateTables(gui,divParams)
            %generates table and properties for the table which shows the
            %metadata of the important sensors
            gui.config
            gui.impSensorsLabel = uitable('Parent', gui.root,...
                'Position', [25 divParams(4)+25 divParams(3) divParams(4)],...
                'Data',gui.data.datamatrix(gui.importantSensors,1:2),...
                'BackgroundColor', [0.9 0.9 1 ;0.5 0.5 1],'FontSize', gui.config.font,...
                'ColumnWidth',gui.config.impTabWidth ,...
                'RowName',[],'ColumnName',{'Label', 'Type'}...
                );
            %generates table and properties for the table which shows the
            %sensor data, is a seperate table because of rendering issues
            gui.impSensorsData = gui.concatUItab(gui.impSensorsLabel,...
            gui.data.datamatrix(gui.importantSensors,3));
            gui.impSensorsData.ColumnFormat = {'shortG'};
            gui.impSensorsData.ColumnWidth = {100};
            gui.impSensorsData.ColumnName = {'Value'};
            gui.impSensorsData.Position(3) = gui.impSensorsData.Extent(3);
            gui.impSensorsLabel.Position(3) = gui.impSensorsLabel.Extent(3);
            gui.impSensorsLabel.Position(4) = gui.impSensorsLabel.Extent(4);
            
            %table which is used to toggle the SI-prefixes of the sensors
            SiTable = cell(size(gui.importantSensors,2),1);
            SiTable(:)  = {'none'};
            gui.convTable = gui.concatUItab(gui.impSensorsData, SiTable);
            gui.convTable.Visible = 'on';
            gui.convTable.ColumnFormat = {gui.siPrefixes};
            gui.convTable.ColumnEditable = [true];
            gui.convTable.CellEditCallback = @cellEditCallback;
            gui.convTable.ColumnName = {'SI'};
            
            %table which shows all sensors, starts hidden
            gui.impSensCheck = false(size(gui.data.datamatrix,1),1);
            gui.impSensCheck(gui.importantSensors) = true;
            gui.impSensCheck = num2cell(gui.impSensCheck);
            gui.allSensors = uitable('Parent', gui.root, 'Position', ...
                [divParams(3)+25 0 divParams(5) divParams(6) ],...
                'Data',[gui.data.datamatrix(:,[1 3])],'RowName',[],...
                'ColumnName',[],'BackgroundColor', [0.9 0.9 1 ],...
                'ColumnWidth', {100,50}, 'Visible','off',...
                'CellSelectionCallback',@showProperties...
                ,'ColumnFormat', {'char','numeric','logical'},...
                'ColumnEditable',[false false true] ...
                );
            gui.allSensors.Position(3) = gui.allSensors.Extent(3)+20;
            showAll = uicontrol('Style','checkbox','Callback',@toggleAll,...
                'Position',[divParams(3)+10 divParams(6)-25 15 15]);
            
            %table which shows the properties of the currently selected
            %sensor
            gui.propTable = uitable('Parent',gui.root, 'Position', ...
                [gui.convTable.Position(1)+ gui.convTable.Position(3)+25,...
                gui.convTable.Position(2)+25, 450, 300],'ColumnEditable', true...
                ,'CellEditCallback',@editProp, 'ColumnFormat',...
                {'char',gui.siPrefixes,'char','numeric','numeric','logical'},...
                'RowName',[],'ColumnName', {'Label','Prefix','Unit','Min','Max','Important'});
            
            %callback function which show the properties of a sensor when
            %selected
            function showProperties(table, event)
                if (size(event.Indices,1) > 0)
                    sensIdx = event.Indices(1);
                    imp = gui.impSensCheck{sensIdx};
                    sensProps = gui.sensorProperties(sensIdx);
                    sensProps = sensProps{1};
                    if (isempty(sensProps) == 1)
                        sensProps = SensorProperties(gui.sensorLabel{sensIdx},...
                        gui.sensorTabel{sensIdx},...
                        gui.sensorMin(sensIdx),gui.sensorMax(sensIdx));
                        gui.sensorProperties(sensIdx) = {sensProps};
                    end
                    gui.propTable.Data = {sensProps.label, sensProps.siOrgPrefix, sensProps.siUnit,...
                        sensProps.minVal,sensProps.maxVal,imp};
                    gui.selectedSensor = sensIdx;
                end
            end
            
            %callback fundtion which saves the edited properties to the
            %global list when a property is edited
            function editProp(table, event)
                propIdx = event.Indices(2);
                sensProps = gui.sensorProperties(gui.selectedSensor);
                sensProps = sensProps{1};
                switch propIdx
                    case 1
                        sensProps.label = event.NewData;
                    case 2
                        sensProps.siOrgPrefix = event.NewData;
                        sensProps.siCurrPrefix = event.NewData;
                        %gui.convTable.Data(gui.selectedSensor) = {sensProps.siOrgPrefix};
                        gui.syncProperties();
                    case 3
                        sensProps.siUnit = event.NewData;
                    case 6
                        updateImpSens(gui.selectedSensor, event.NewData);
                    otherwise
                end
                gui.sensorProperties(gui.selectedSensor) = {sensProps};
                gui.saveProperties();
            end
            
            %callback function for selecting another SI-prefix to correctly
            %transform the data
            function cellEditCallback(hTable, editEvent)
                if(~isempty(gui.sensorProperties{editEvent.Indices(1)}))
                    basePrefix = gui.sensorProperties{editEvent.Indices(1)}.siOrgPrefix;
                else
                    basePrefix = 'none';
                end
                newPreFix= editEvent.NewData;
                
                baseidx = find(strcmp(basePrefix,gui.siPrefixes));
                newidx = find(strcmp(newPreFix,gui.siPrefixes));
                
                basefn = gui.siTransformations{baseidx};
                newfn = gui.siTransformations{newidx};
                
                convfn = @(x)x*( newfn(1)/basefn(1));
                
                gui.sensorTranforms = [gui.sensorTranforms {{editEvent.Indices(1) convfn}}];
            end
            
            %function for toggeling the visibility of the All Sensors table
            function toggleAll(hObject,eventData)
                if(get(hObject,'Value') == get(hObject,'Max'))
                    gui.allSensors.Visible = 'on';
                else
                    gui.allSensors.Visible = 'off';
                end
            end
            
            function updateImpSens(idx, NewData)
                if(NewData)
                    gui.importantSensors = [gui.importantSensors idx];
                    gui.convTable.Data =  [gui.convTable.Data; 'none'];
                else
                    tidx = gui.importantSensors==idx;
                    gui.convTable.Data(tidx) =[];
                    gui.importantSensors = gui.importantSensors(gui.importantSensors~=idx);
                end
                gui.impSensCheck{idx} =  NewData;
                gui.impSensorsLabel.Data = gui.data.datamatrix(gui.importantSensors,1:2);
                gui.impSensorsData.Data = gui.data.datamatrix(gui.importantSensors,3);
                gui.syncProperties();
            end
        end
        
        %creates the graphs
        function generateGraphs(gui, naxes,divParams)
            
            gui.graph = axes('Units','pixels', 'Position', ...
            [25,25,(divParams(3)/naxes)-25,divParams(4)-25]);
            gui.graph.Units = 'normalized';
            gui.graph.Title.String = gui.data.returnEntry(gui.graphSensors(1),1);
            gui.graph2 = axes('Units','pixels', 'Position', ...
            [25+(divParams(3)/naxes),25,(divParams(3)/naxes)-25,divParams(4)-25] );
            gui.graph2.Units = 'normalized';
            gui.graph2.Title.String = gui.data.returnEntry(gui.graphSensors(2),1);
            
            
            gui.ddg1 = uicontrol('Style', 'popup',...
                'String', gui.sensorLabel,...
                'Position', [25 divParams(4)-25 100 50]...
                );
            gui.ddg1.Position
            gui.ddg2 = uicontrol('Style', 'popup',...
                'String', gui.sensorLabel,'Value',2,...
                'Position', [25+(divParams(3)/naxes) divParams(4)-25 100 50]...
                );
        end
        
        %converts the data according to the settings in the data table
        function convData = convertData(gui, data)
            convData = data;
            cellfun(@convDataLine,gui.sensorTranforms);
            
            function convDataLine(x)
                convData{x{1}} = x{2}(data{x{1}});
            end
        end
        %updates the sensor tables in the GUI
        function update(gui,data, updateAll)
            outlierIdx = gui.checkValues(data.returnColumn(3));
            gui.graphSensors(1)=gui.ddg1.Value;
            gui.graphSensors(2)=gui.ddg2.Value;
            
            if(size(outlierIdx,1) > 0)
                gui.allSensors.Data = ...
                [gui.markoutliers(outlierIdx,data.datamatrix(:,[1 3])) gui.impSensCheck];
            end
            
            gui.impSensorsData.Data = ...
                gui.convertData(data.datamatrix(gui.importantSensors,3));
            if(updateAll)
                gui.allSensors.Data = [data.datamatrix(:,[1 3]) gui.impSensCheck];
            end
            gui.updateDatabacklog(data);
            
            
            axes(gui.graph2);
            plot(gui.dataSlidingWindow(gui.graphSensors(2),:));
            gui.graph2.Title.String = data.returnEntry(gui.graphSensors(2),1);
            
            axes(gui.graph);
            plot(gui.dataSlidingWindow(gui.graphSensors(1),:));
            gui.graph.Title.String = data.returnEntry(gui.graphSensors(1),1);
            drawnow;
        end
        %saves the sensor properties from file
        function saveProperties(gui)
            sensProps = gui.sensorProperties;
            save('Properties.mat', 'sensProps')
        end
        %loads the sensor properties from file
        function loadProperties(gui)
            load('Properties.mat');
            gui.sensorProperties = sensProps;
            gui.syncProperties();
        end
        %synchronises the Property List with the tables
        function syncProperties(gui, sensorIdx)
            idxs =  [1:size(gui.importantSensors,2)];
            tmpCondata = gui.convTable.Data;
            arrayfun(@syncsensor, gui.importantSensors,idxs);
            gui.convTable.Data = tmpCondata;
            drawnow();
            function syncsensor(sensid, tabid)
                sensorC = gui.sensorProperties{sensid}
                if ( ~(isempty(sensorC)) & (isempty(sensorC.siOrgPrefix)) )
                    sensorC.siOrgPrefix = 'none';
                end
                if( (isempty(sensorC) == 0) &...
                    ~strcmp(tmpCondata{tabid}, sensorC.siOrgPrefix) )
                    tmpCondata{tabid} = sensorC.siOrgPrefix;
                end
            end
        end
        function exIdx = checkValues(gui,data)
            datarr = cell2mat(data);
            mincm = gui.sensorMin < datarr;
            maxcm = gui.sensorMax > datarr;
            exIdx = find(mincm | maxcm);
        end
        function data = markoutliers(gui, outliers,data)
            arrayfun(@markrow, outliers);
            function markrow(idx)
                data{idx,2} =  gui.colorgen('#FF0000',num2str(data{idx,2}));
            end
        end
        function updateDatabacklog(gui, data)
            idx = gui.backlogPointer
            newdata = cell2mat(data.datamatrix(:,3));
            gui.databacklog(:,gui.backlogPointer) = newdata;

            tail = gui.databacklog(:,gui.backlogPointer+1 : end)
            head = gui.databacklog(:,1 : gui.backlogPointer)
            
            gui.dataSlidingWindow = [tail head];
            gui.backlogPointer = mod(gui.backlogPointer,gui.backlogSize) + 1;
        end
    end
end

