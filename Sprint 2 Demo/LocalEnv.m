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
                obj.currentData = SensorDataContainer(SensorDataContainer.convertLocalData(importdata(filename),6));
            end
        end
        
        % Function: updateData
        % Functionality: Permutate the current data for test purposes.
        function obj = updateData(obj)
            rndVals = cellfun(@(x) x*(rand(1)+0.5),obj.currentData.returnColumn(3),'un',0);
            obj.currentData.setColumn(3,transpose(rndVals));
        end
    end
end

