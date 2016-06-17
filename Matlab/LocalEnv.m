classdef LocalEnv < Env
    %LOCALENV Setup the environment for local usage of data
    %   Setup the environment for local usage of data
    methods
        % Function: LocalEnv
        % Functionality: Constructs the Local Environment
        function obj = LocalEnv(filename)
            if nargin == 0
                obj.currentData = {};
            else
                data = importdata(filename);
                if(isa(data,'SensorDataContainer'))
                    obj.currentData = data;
                else
                    obj.currentData = SensorDataContainer(SensorDataContainer.convertLocalData(data,6));
                end
            end
        end
        
        
        % Function: updateData
        % Functionality: Permutate the current data for test purposes.
        function obj = updateData(obj)
            if(nargin == 0 || rand(1) > 0.5)
                obj.hasNewData = false;
            else
                rndVals = cellfun(@(x) x*(rand(1)+0.5),obj.currentData.returnColumn(3),'un',0);
                obj.currentData.setColumn(3,transpose(rndVals));
                obj.hasNewData = true;
            end
        end
    end
end

