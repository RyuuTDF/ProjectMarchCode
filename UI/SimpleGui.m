
classdef SimpleGui <handle
    % SIMPLEGUI Shows a graphical representation of the send data using
    % tables and graphs
    
    properties
        config; % used to save the configuration file
        env = Env();% contains the used environment
        data = {};% contains all initial data
        
        sensorLabel = {};% list of all sensor labels
        sensorTabel = {};% list of inital data of all sensors
        sensorMin = [];% array of all sensor minima
        sensorMax = [];% array of all sensor maxima
        sensorOutlier = []; %array of sensors which have had an outlying value
        
        importantSensors = [];% array of all important sensors
        impSensCheck; % boolean representation of important sensors
        
        sensorProperties;  % list of all sensor properties
        selectedSensor; % index of the currently selected sensor
        
        % enumeration of relevant SI Prefixes and corresponding
        % transformations
        siPrefixes = {'G'    'M'    'k'    'h'    'da'...
            'none'  'd'    'c'    'm'    'µ'    'n'};
        siTransformations = {@(x)x*10^-9    @(x)x*10^-6    @(x)x*10^-3    ...
            @(x)x*10^-2    @(x)x*10^-1    @(x)x*10^0    @(x)x*10^1 ...
            @(x)x*10^2    @(x)x*10^3 ...
            @(x)x*10^6    @(x)x*10^9};
        
        sensorSiTrans;% list of SiTransformations for each sensor
        transIdx; %list of sensors with an non_f(x)=x transformation
        
        impSensorsLabel; % UItable which contains properties of the important sensors
        impSensorsData; % UItable which shows the data of the important sensors
        allSensors; % UItable which contains all sensors
        convTable; % UItable with the SI Prefixes of the important sensors
        propTable; % UItable which shows the properties of the selected sensor
        
        % axes which show data and the dropdown menus which select which
        % sensors have to be shown
        graph;
        graph2;
        ddg1;
        ddg2;
        line1;
        line2;
        
        graph3;
        graph4;
        ddg3;
        ddg4;
        line3;
        line4;
        
        root;% base figure of the simpleGUI
        
        
        updateFlag = true; % is used to check of the data should be updates for testing purposes
        updateRate;%base frequency of updates
        graphRate;
        impRate;
        allRate;
        
        graphSensors ={[1 3], 2,3,4};%inital values of sensors shown in the graph
        
        % stores the old data used in the graph and constructs a sliding window
        % to show the data in the right order
        databacklog;
        dataSlidingWindow;
        backlogPointer;
        backlogSize;
    end
    
    methods(Static)
        % Function: streamTest
        % Functionality: Gets the configuration and setup the GUI
        function gui = streamTest
            
            config = importdata('GuiConfig.mat');
            config = SimpleGui.resize(config);
            % Sets up the environment
            if(strcmp(config.env,'local'))
                env = LocalEnv(config.src);
            else
                env = NetworkEnv();
            end
            
            while isempty(env.currentData)
                env = updateData(env);
            end
            
            gui= SimpleGui(env.currentData,config);
            updateCheck = uicontrol('Style','checkbox','Callback',@updateC,...
                'Position',[(gui.root.Position(3)*0.8)-350,650,75,25],...
                'String','Update'...
            );
            
            % Function: updateC
            % Functionality: callback function for the update checkbox
            % updates GUI when the checkbox is marked
            function updateC(hObject, eventdata, handles)
                gui.updateFlag = get(hObject,'Value') == get(hObject,'Max');
                if (get(hObject,'Value') == get(hObject,'Max'))
                    tic;
                else
                    toc
                end
                cnt =0;
                
                while gui.updateFlag;
                    allUpdate= gui.updateRate;
                    impUpdate= gui.updateRate;
                    graphUpdate = gui.updateRate;

                    cnt = cnt+1;    
                    currUpdateRate = cnt/toc;
                    env = updateData(env);
                    
                    if(env.hasNewData)
                        gui.update(env.currentData, mod(cnt,allUpdate) ==0,...
                        mod(cnt,impUpdate)==0,mod(cnt,graphUpdate)==0);
                    else
                        pause(gui.updateRate);
                    end
                end
            end
            
            recbox = uicontrol('Style','checkbox','Callback',@toggleRecording,...
                'Position',[divParams(3)-350 divParams(6)-100 150 25],...
                'String','Toggle Recording'...
                );
            % Function: updateC
            % Functionality: callback function for the update checkbox
            % updates GUI when the checkbox is marked            
            function toggleRecording(hObject, eventdata, handles)
                record = get(hObject,'Value') == get(hObject,'Max');
                if(~strcmp(config.env,'local'))
                    if(record)
                        %start recording
                        env.startRecording();
                    else
                        %end recording
                        env.stopRecording();
                    end
                end
            end
        end
        
        
        
        % Function: concatUItab
        % Functionality: generates a uitable with 'data' with the same properties
        % as the base table and has the right bottom corner of the base table as
        % left bottom corner
        function newTable = concatUItab(baseTable,data)
            newTable = uitable();
            newTable.Data = data;
            
            newTable.Position(1) = baseTable.Position(1)+baseTable.Extent(3);
            newTable.Position(2) = baseTable.Position(2);
            newTable.Position(3) = newTable.Extent(3);
            newTable.Position(4) = baseTable.Position(4);
            
            newTable.BackgroundColor = baseTable.BackgroundColor;
            newTable.FontSize = baseTable.FontSize;
            newTable.ColumnName =  [];
            newTable.RowName = baseTable.RowName;
        end
        
        % Function: resize
        % Functionality: changes size related properties in
        % the configuration file based on the size setting
        function config = resize(config)
            switch config.size
                case 's';
                    config.figPos = config.figPosS;
                    config.font = config.fontS;
                    config.impTabWidth = config.impTabWidthS;
                    config.naxes = 2;
                case 'm'
                    config.figPos=config.figPosM;
                    config.font = config.fontM;
                    config.impTabWidth = config.impTabWidthM;
                    config.naxes = 2;
                case 'l'
                    config.figPos=config.figPosL;
                    config.naxes = 4;
%                     config.font = config.fontL;
%                     config.impTabWidth = config.impTabWidthL;
            end
        end
        
        % Function: colorgen
        % Functionality: generates html for cell coloring
        function html = colorgen(color,str)
            html = ['<html><table border=0 width=400 bgcolor=',color,...
                '><TR><TD>',str,'</TD></TR> </table></html>'];
        end
    end
    
    methods
        % Function: SimpleGui
        % Functionality: constructor
        function gui = SimpleGui(sensorData, config)
            gui.config = config;
            importantSensors = config.impSens;
            %r emoves all open figures for a clean slate
            close all;
            if(nargin >0)
                % sets the data properties
                gui.data=sensorData;
                sensorData.datamatrix
                gui.sensorLabel = sensorData.returnColumn(1);
                gui.sensorTabel = sensorData.returnColumn(2);
                gui.sensorMin = cell2mat(sensorData.returnColumn(3));
                gui.sensorMax = cell2mat(sensorData.returnColumn(4));
                gui.importantSensors = importantSensors;
                gui.sensorProperties = cell(size(gui.data.datamatrix,1),1);
                
                gui.updateRate = config.updateFreq;
                gui.graphRate = config.graphUpdateRate;
                gui.impRate = config.impUpdateRate;
                gui.allRate = config.allUpdateRate;
                
                
                % calls the figure object and defines some margins
                gui.root = figure('Position',config.figPos , 'MenuBar', 'None','Resize','off');
                divParams =[
                    gui.root.Position(1)+(gui.root.Position(3)*0.8)
                    gui.root.Position(2)+(gui.root.Position(4)*0.5)
                    gui.root.Position(3)*0.8
                    gui.root.Position(4)*0.5
                    gui.root.Position(3)*0.2
                    gui.root.Position(4)
                    ];
                gui.sensorSiTrans = cell(size(gui.data.datamatrix,1),1);
                
                % defines the amount of axes in the figure
                naxes = config.naxes;
                gui.backlogSize=config.backlogSize;
                % used to save the incoming data
                gui.databacklog = zeros(size(gui.data.datamatrix,1),gui.backlogSize);
                gui.dataSlidingWindow = zeros(size(gui.data.datamatrix,1),gui.backlogSize);
                gui.backlogPointer = 1;
                % generates other graphic items
                gui.generateGraphs(naxes,divParams);
                gui.generateTables(divParams);
                gui.loadProperties();
            end   
        end
        

        % Function: generateTable
        % Functionality: creates tables used to show data
        function generateTables(gui,divParams)
            % generates table and properties for the table which shows the
            % metadata of the important sensors
            
            sensorLabels = cell2mat(gui.data.datamatrix(:,2));
            gui.data.datamatrix(:,2) = gui.config.typetable(sensorLabels);
            
            gui.impSensorsLabel = uitable('Parent', gui.root,...
                'Position', [25 divParams(4)+75 divParams(3)+25 divParams(4)-75],...
                'Data',gui.data.datamatrix(gui.importantSensors,1:2),...
                'BackgroundColor', [0.9 0.9 1 ;0.5 0.5 1],'FontSize', gui.config.font,...
                'ColumnWidth',gui.config.impTabWidth ,...
                'RowName',[],'ColumnName',{'Label', 'Type'}...
                );
            % generates table and properties for the table which shows the
            % sensor data, is a seperate table because of rendering issues
            gui.impSensorsLabel.Position(3) = gui.impSensorsLabel.Extent(3);
            
            
            gui.impSensorsData = gui.concatUItab(gui.impSensorsLabel,...
                gui.data.datamatrix(gui.importantSensors,3));
            gui.impSensorsData.ColumnFormat = {'shortG'};
            gui.impSensorsData.ColumnWidth = {150};
            gui.impSensorsData.ColumnName = {'Value'};
            gui.impSensorsData.Position(3) = gui.impSensorsData.Extent(3);
            
            % table which is used to toggle the SI-prefixes of the sensors
            SiTable = cell(size(gui.importantSensors,2),1);
            SiTable(:)  = {'none'};
            gui.convTable = gui.concatUItab(gui.impSensorsData, SiTable);
            gui.convTable.Visible = 'on';
            gui.convTable.ColumnFormat = {gui.siPrefixes};
            gui.convTable.ColumnEditable = [true];
            gui.convTable.CellEditCallback = @cellEditCallback;
            gui.convTable.ColumnName = {'SI'};
            
            % constructs boolean representation of the important sensors
            gui.impSensCheck = false(size(gui.data.datamatrix,1),1);
            gui.impSensCheck(gui.importantSensors) = true;
            gui.impSensCheck = num2cell(gui.impSensCheck);
            
            % table which shows all sensors, starts hidden
            gui.allSensors = uitable('Parent', gui.root, 'Position', ...
                [divParams(3)+25 0 divParams(5) divParams(6) ],...
                'Data',[gui.data.datamatrix(:,[1 3])],'RowName',[],...
                'ColumnName',[],'BackgroundColor', [0.9 0.9 1 ],...
                'ColumnWidth', {100,75}, 'Visible','off',...
                'CellSelectionCallback',@showProperties...
                ,'ColumnFormat', {'char','numeric','logical'},...
                'ColumnEditable',[false false true] ...
                );
            gui.allSensors.Position(3) = gui.allSensors.Extent(3)+20;
            
            %toggle for showing the all sensors table
            showAll = uicontrol('Style','checkbox','Callback',@toggleAll,...
                'Position',[divParams(3)-350 divParams(6)-70 150 25],...
                'String','Show all sensors table'...
            );
            
            %table which shows the properties of the currently selected
            %sensor
            gui.propTable = uitable('Parent',gui.root, 'Position', ...
                [gui.convTable.Position(1)+ gui.convTable.Position(3)+25,...
                gui.convTable.Position(2), 350, 75],'ColumnEditable', true...
                ,'CellEditCallback',@editProp, 'ColumnFormat',...
                {'char',gui.siPrefixes,'char','numeric','numeric','logical'},...
                'RowName',[],'ColumnName', ...
                {'Label','Prefix','Unit','Max','Min','Important'},...
                'ColumnWidth',{75,50,50,50,50,50}...
                );
            formulaField = uicontrol('Style','edit',...
                'Position', [gui.propTable.Position(1:3) 30]...
                ,'Callback',@editFormula...
                );
            
            % table for controlling the update speed of certain components
                updateChangeTable = uitable('Parent',gui.root, 'Position',...
                [gui.propTable.Position(1), sum(gui.propTable.Position([2 4])),...
                350 , 50], 'ColumnEditable', true, 'RowName',[],'ColumnName',...
                {'Base','Graphs','All','Import'},'ColumnFormat',{'numeric'},'ColumnWidth',{75 75,75,75}...
                ,'CellEditCallback',@changeUpdateFreq...
            );
            updateChangeTable.Data = {gui.updateRate, gui.graphRate, gui.allRate, gui.impRate}
            
            % Function: showProperties
            % Functionality: callback function which show the properties
            % of a sensor when selected
            function showProperties(table, event)
                
                if (size(event.Indices,1) > 0)
                    % gets the index en properties of the sensor
                    sensIdx = event.Indices(1);
                    imp = gui.impSensCheck{sensIdx};
                    sensProps = gui.sensorProperties(sensIdx);
                    sensProps = sensProps{1};
                    
                    % creates a new entry in the properties list if this
                    % does not excist yet
                    if (isempty(sensProps) == 1)
                        sensProps = SensorProperties(gui.sensorLabel{sensIdx},...
                            gui.sensorTabel{sensIdx},...
                            gui.sensorMin(sensIdx),gui.sensorMax(sensIdx));
                        gui.sensorProperties(sensIdx) = {sensProps};
                    end
                    
                    % shows the properties in the table
                    gui.propTable.Data = {sensProps.label, sensProps.siOrgPrefix, sensProps.siUnit,...
                        sensProps.transformation(sensProps.minVal),sensProps.transformation(sensProps.maxVal),imp};
                    formulaField.String = func2str(sensProps.transformation);
                    gui.selectedSensor = sensIdx;
                end
            end
            
            % Function: editProp
            % Functionality :callback function which saves the edited
            % properties to the global list when a property is edited
            function editProp(table, event)
                % gets the index of the property
                % 1: Label
                % 2: SI Prefix
                % 3: SI Unit
                % 6: Being an important sensor
                propIdx = event.Indices(2);
                sensProps = gui.sensorProperties(gui.selectedSensor);
                sensProps = sensProps{1};
                switch propIdx
                    case 1
                        sensProps.label = event.NewData;
                    case 2
                        sensProps.siOrgPrefix = event.NewData;
                        sensProps.siCurrPrefix = event.NewData;
                        gui.syncProperties();
                    case 3
                        sensProps.siUnit = event.NewData;
                    case 6
                        updateImpSens(gui.selectedSensor, event.NewData);
                    otherwise
                end
                % saves the changes
                gui.sensorProperties(gui.selectedSensor) = {sensProps};
                gui.saveProperties();
            end
            
            % Function: cellEditCallback
            % Functionality: callback function for selecting another
            % SI-prefix to correctlyn transform the data
            function cellEditCallback(hTable, editEvent)
                gui.transformSiData(editEvent.Indices(1),editEvent.NewData);
            end
            
            % Function: toggleAll
            % Functionality: function for toggeling the visibility
            % of the All Sensors table
            function toggleAll(hObject,eventData)
                if(get(hObject,'Value') == get(hObject,'Max'))
                    gui.allSensors.Visible = 'on';
                else
                    gui.allSensors.Visible = 'off';
                end
            end
            
            % Function: updateImpSens
            % Functionality:
            % updates the important sensor window with the currently
            % selected important sensors
            function updateImpSens(idx, NewData)
                %if NewData is true, add the selected sensor to the Imporant
                %Sensor list, else, remove the selceted sensor from the
                %list
                if(NewData)
                    gui.importantSensors = [gui.importantSensors idx];
                    gui.convTable.Data =  [gui.convTable.Data; 'none'];
                else
                    tidx = gui.importantSensors==idx;
                    gui.convTable.Data(tidx) =[];
                    gui.importantSensors = gui.importantSensors(gui.importantSensors~=idx);
                end
                gui.impSensCheck{idx} =  NewData;
                % redraw the important sensor tables
                gui.impSensorsLabel.Data = gui.data.datamatrix(gui.importantSensors,1:2);
                gui.impSensorsData.Data = gui.data.datamatrix(gui.importantSensors,3);
                gui.syncProperties();
            end
            
            % Function: editFormula
            % Functionality: callback for when the transformation field is
            % changed; applies the new formula to the relevant data
            function editFormula(control, event)
                sensProps = gui.sensorProperties(gui.selectedSensor);
                sensProps = sensProps{1};   
                sensProps.transformation = str2func(control.String);
                
                wasTrans = any(gui.transIdx(:)==gui.selectedSensor);
                isTrans = ~strcmp(control.String,'@(x)x') ;
                
                if(wasTrans && ~isTrans)
                    gui.transIdx(gui.transIdx == gui.selectedSensor) = [];
                end
                if(~wasTrans && isTrans)
                    gui.transIdx = [gui.transIdx gui.selectedSensor];
                end
                    
                gui.sensorProperties(gui.selectedSensor) = {sensProps};
                gui.saveProperties();
                gui.syncProperties();
            end
            
            % Function: changeUpdateFreq
            % Functionality: changes update frequency of the visual
            % elements
            function changeUpdateFreq(control, event)
                control
                event
                switch event.Indices(2) 
                    case 1
                        gui.updateRate = event.NewData;
                    case 2
                        gui.graphRate = event.NewData;                        
                    case 3                        
                        gui.allRate = event.NewData;
                    case 4                        
                        gui.impRate = event.NewData;  
                end
            end
            
        end
        
        % Function: generateGraphs
        % Functionality: creates the graphs
        function generateGraphs(gui, naxes,divParams)
            
            if(naxes >2) 
               divParams(3) = divParams(3)+25;
               divParams(4)= divParams(4)-25; 
            end
            gui.graph = axes('Units','pixels', 'Position', ...
                [25,25,(divParams(3)/naxes)-25,divParams(4)-25]);
            gui.graph.Units = 'normalized';
            gui.graph.Title.String = 'Graph 1';
            gui.graph2 = axes('Units','pixels', 'Position', ...
                [25+(divParams(3)/naxes),25,(divParams(3)/naxes)-25,divParams(4)-25] );
            gui.graph2.Units = 'normalized';
            gui.graph2.Title.String = 'Graph 2';
            
            if(naxes >2)
                gui.graph3 = axes('Units','pixels', 'Position', ...
                    [25+(2*divParams(3)/naxes),25,(divParams(3)/naxes)-25,divParams(4)-25]);
                gui.graph3.Units = 'normalized';
                gui.graph3.Title.String = 'Graph 3';
                gui.graph4 = axes('Units','pixels', 'Position', ...
                    [25+(3*divParams(3)/naxes),25,(divParams(3)/naxes)-25,divParams(4)-25] );
                gui.graph4.Units = 'normalized';
                gui.graph4.Title.String = 'Graph 4'; 
                
            gui.ddg3 = uicontrol('Style', 'listbox',...
                'String', gui.sensorLabel,...
                'Position', [25+(2*divParams(3)/naxes) divParams(4) 125 75],...
                'Max',7 ...
                );
            gui.ddg4 = uicontrol('Style', 'listbox',...
                'String', gui.sensorLabel,'Value',2,...
                'Position', [25+(3*divParams(3)/naxes) divParams(4) 125 75]...
                ,'Max', 7 ...
                );
            end
            
            gui.ddg1 = uicontrol('Style', 'listbox',...
                'String', gui.sensorLabel,...
                'Position', [25 divParams(4) 125 75],...
                'Max',7 ...
                );
            gui.ddg2 = uicontrol('Style', 'listbox',...
                'String', gui.sensorLabel,'Value',2,...
                'Position', [25+(divParams(3)/naxes) divParams(4) 125 75]...
                ,'Max', 7 ...
                );
        end
        
        % Function: convertData
        % Functionality: transforms the data according to the SI unit and
        % transformation formula assigned to the respective sensor
        function convData = convertData(gui, data,selection)
            convData = data;
            tabidxs =  1:size(data,1);
            % Gets the indices of the sensors based on the table the data
            % is written to
            switch selection
                case 'imp'
                    sensidxs = gui.importantSensors;
                otherwise
                    sensidxs = 1:size(data,1);
                    [transSensIdxs, transTabIdxs, x] = intersect(sensidxs, gui.transIdx);
                    sensidxs = transSensIdxs;
                    tabidxs = transpose(transTabIdxs);
            end
            
            if(~isempty(sensidxs))    
                arrayfun(@convDataLine,sensidxs,tabidxs )
            end
            
            % Function: convDataLine
            % Functionality: transform data of sensor represented by
            % sensIdx
            function convDataLine(sensIdx,tabIdx)
                %gets the properties of the sensor and checks if empty
                prop = gui.sensorProperties{sensIdx};
                if(~isempty(prop))
                    siFn = gui.sensorSiTrans{sensIdx};
                    % if no SI function is assigned, generate one
                    if(isempty(siFn))
                        siFn= @(x)x;
                    end
                    
                    fn = prop.transformation;
                    % Determines which part of the data should be
                    % transformed
                    switch selection
                        case 'imp'                             
                            convData{tabIdx} = siFn(fn(data{tabIdx}));
                        case 'all'
                            convData{tabIdx,2} = fn(data{tabIdx,2});
                        case 'log'
                            convData{sensIdx} = fn(data{sensIdx});
                        otherwise
                    end
                end
            end
        end
        
        % Function: update
        % Functionality: updates the sensor tables and graphs in the GUI
        function update(gui,data, updateAll,updateImp,updateGraph)
            % checks if all sensor data is in the defined range
            outlierIdx = gui.checkValues(data.returnColumn(3));
            
            % if a value is not in the defined range, mark the outlier
%             if(size(gui.sensorOutlier,1) > 0)
%                 gui.allSensors.Data = ...
%                     gui.markoutliers(gui.sensorOutlier,gui.convertData(data.datamatrix(:,[1 3]),'all'));
%             end
            % updates the imporant sensor if the flag is set to true
            if(updateImp)
                gui.impSensorsData.Data = ...
                    gui.convertData(data.datamatrix(gui.importantSensors,3),'imp');
            end
            % updates all sensordata if the flas is set to true
            if(updateAll)
                gui.allSensors.Data = gui.convertData(data.datamatrix(:,[1 3]),'all');
            end
            
            % updates the graphs
            gui.updateDatabacklog(data);
            
            if(updateGraph)
                gui.updateSlidingWindow();
                gui.graphSensors{1}=gui.ddg1.Value;
                gui.graphSensors{2}=gui.ddg2.Value;

                gui.plotLine(transpose(gui.dataSlidingWindow(gui.graphSensors{2},:)),gui.graph2,2);
                gui.plotLine(transpose(gui.dataSlidingWindow(gui.graphSensors{1},:)),gui.graph,1);
                
                if(gui.config.naxes >2)
                    gui.graphSensors{3}=gui.ddg3.Value;
                    gui.graphSensors{4}=gui.ddg4.Value;

                    gui.plotLine(transpose(gui.dataSlidingWindow(gui.graphSensors{3},:)),gui.graph3,3);
                    gui.plotLine(transpose(gui.dataSlidingWindow(gui.graphSensors{4},:)),gui.graph4,4);
                end
            end
            
            drawnow limitrate;
        end
        
        % Function: saveProperties
        % Functionality: saves the sensor properties to file
        function saveProperties(gui)    
            sensProps = gui.sensorProperties;
            save('Properties.mat', 'sensProps');
        end
        
        % Function: loadProperties
        % Functionality: loads the sensor properties from file
        function loadProperties(gui)
            load('Properties.mat');
            if(isempty(sensProps))
                sensProps = cell(size(gui.data.datamatrix,1),1);
            end
            gui.sensorProperties = sensProps;
            gui.syncProperties();
            gui.setTransIdx();
        end
        
        % Function: setTransIdx
        % Functionality: fills the transIdx list based on the sensor
        % properties
        
        function setTransIdx(gui)
            gui.transIdx = [];
            sensidxs = 1:size(gui.sensorProperties,1);
            
            arrayfun(@checkSensTrans,sensidxs)
            function checkSensTrans(sensIdx)
                sens = gui.sensorProperties{sensIdx};
                if(~isempty(sens))
                    isTrans = ~strcmp(func2str(sens.transformation),'@(x)x');
                    if(isTrans)
                        gui.transIdx = [gui.transIdx sensIdx];
                    end
                end
            end
        end
                       
        % Function: resetProperties
        % Funcionality: removes all sensor properties from file
        function resetProperties(gui)
            gui.sensorProperties = {};
            gui.saveProperties();
        end
        
        % Function: syncProperties
        % Functionality: synchronises the SI-prefix with the tables
        function syncProperties(gui)
            idxs =  [1:size(gui.importantSensors,2)];
            tmpCondata = gui.convTable.Data;
            if(~isempty(gui.importantSensors))
                arrayfun(@syncSensor, gui.importantSensors,idxs);
            end
            gui.convTable.Data = tmpCondata;
            gui.scaleSI();
            
            % Function: syncSensor
            % Functionality: checks if the SI-prefix of the sensor changed
            function syncSensor(sensid, tabid)
                sensorC = gui.sensorProperties{sensid};
                if ( ~(isempty(sensorC)) & (isempty(sensorC.siOrgPrefix)) )
                    sensorC.siOrgPrefix = 'none';
                end
                if( (isempty(sensorC) == 0) &...
                        ~strcmp(tmpCondata{tabid}, sensorC.siOrgPrefix) )
                    tmpCondata{tabid} = sensorC.siOrgPrefix;
                end
            end
        end
        
        % Function: checkValues
        % Functionality: checks for the given data whether they are between
        % the given minimum and maximum
        function exIdx = checkValues(gui,data)
            datarr = cell2mat(data);
            mincm = gui.sensorMin < datarr;
            maxcm = gui.sensorMax > datarr;
            exIdx = find(mincm | maxcm);
            gui.sensorOutlier = union(gui.sensorOutlier,exIdx);
        end
        
        % Function: markoutliers
        % Functionality; marks the sensors which data is outside the range
        % red
        function data = markoutliers(gui, outliers,data)
            arrayfun(@markrow, outliers);
            function markrow(idx)
                data{idx,2} =  gui.colorgen('#FF0000',num2str(data{idx,2}));
            end
        end
        
        % Function: updateDatabacklog
        % Functionality: saves the data in a ring buffer in order to
        % plot in on the graph
        function updateDatabacklog(gui, data)
            %           newdata = cell2mat(gui.convertData(data.datamatrix(:,3),'log'));
            newdata = cell2mat(data.datamatrix(:,3));
            
            gui.databacklog(:,gui.backlogPointer) = newdata;
            
            gui.backlogPointer = mod(gui.backlogPointer,gui.backlogSize) + 1;
        end
        
        % Function: updateSlidingWindow
        % Functionality: creates an ordered array out of the ring buffer        
        function updateSlidingWindow(gui)
            tail = gui.databacklog(:,gui.backlogPointer+1 : end);
            head = gui.databacklog(:,1 : gui.backlogPointer);
            
            gui.dataSlidingWindow = [tail head];
        end
        
        % Function: plotLine
        % Functionality: draws a line as one would expect when using the
        % plot function, but without computational overhead
        function plotLine(gui,mat,ax,id)
            dims = size(mat);
            idxs = (1:dims(1)).';
            switch id
                case 1
                    delete(gui.line1);
                    gui.line1 = line(idxs,mat, 'Parent',ax);
                case 2
                    delete(gui.line2);                    
                    gui.line2 = line(idxs,mat, 'Parent',ax);
                case 3
                    delete(gui.line3);
                    gui.line3 = line(idxs,mat, 'Parent',ax);
                case 4
                    delete(gui.line4);                    
                    gui.line4 = line(idxs,mat, 'Parent',ax);                    
                otherwise
            end
        end
        
        % Function: transformSiData
        % Functionality: calculates the Si Transformation for a sensor
        % based on the new Prefix
        function transformSiData(gui,tableIdx,newPreFix)
            sensorIdx = gui.importantSensors(tableIdx);
            if(~isempty(gui.sensorProperties{sensorIdx}))
                basePrefix = gui.sensorProperties{sensorIdx}.siOrgPrefix;
            else
                basePrefix = 'none';
            end
            
            baseidx = find(strcmp(basePrefix,gui.siPrefixes));
            newidx = find(strcmp(newPreFix,gui.siPrefixes));
            
            basefn = gui.siTransformations{baseidx};
            newfn = gui.siTransformations{newidx};
            
            convfn = @(x)x*( newfn(1)/basefn(1));
            
            gui.sensorSiTrans{sensorIdx} = convfn;
        end
        
        % Function: aggregateData
        % Functionality: returns an array with the averages of the last 'n'
        % sensor values received by the system
        function out = aggregateData(gui, n)
            baseData = gui.dataSlidingWindow(:,end-n:end);
            out = mean(baseData,2);
        end
        
        
        % Function: scaleSI
        % Functionality: determines the best SI-prefix for all important sensors
        function scaleSI(gui)
            sensorIds = gui.importantSensors;
            tableIds = [1:size(sensorIds,2)];
            if(~isempty(sensorIds))
            arrayfun(@scaleEntry, tableIds,sensorIds);
            end
            % Function: scaleEntry
            % Functionality: determines the best SI-prefix for given sensors
            function scaleEntry(tableIdx, sensIdx)
                val = gui.impSensorsData.Data{tableIdx};
                orgPrefix = gui.sensorProperties{sensIdx}.siOrgPrefix;
                trans =  gui.siTransformations{find(strcmp(orgPrefix,gui.siPrefixes))};
                transfn = @(x)x / trans(1);
                val = transfn(val);
                exp = floor(log10(val));
                switch exp
                    case num2cell(0:2)
                        siPrefix='none';
                        exp = 0;
                    case num2cell(3:5)
                        siPrefix='k';
                        exp = 3;
                    case num2cell(6:8)
                        siPrefix='M';
                        exp = 6;
                    case num2cell(9:11)
                        siPrefix='G';
                        exp = 9;
                    case num2cell(-3:-1)
                        siPrefix='m';
                        exp = -3;
                    case num2cell(-6:-4)
                        siPrefix='µ';
                        exp = -6;
                    case num2cell(-7:-10)
                        siPrefix='n';
                        exp = -9;
                    otherwise
                        siPrefix='none';
                        exp = 0;
                end                
                gui.convTable.Data{tableIdx} = siPrefix;

                gui.transformSiData(tableIdx,siPrefix);
            end
        end
    end
end

    