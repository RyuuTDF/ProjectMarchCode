classdef LocalEnv < Env
    %LOCALENV Setup the environment for local usage of data
    %   Setup the environment for local usage of data
    
	properties
    end

	methods
        %Setup the network environment
        function obj = LocalEnv(filename)
            if nargin == 0
                obj.currentdata = {};
            else
                obj.currentdata = SensorDataContainer(SensorDataContainer.convertLocalData(importdata(filename),6));
            end
        end
        
        %Permutate the current data for test purposes.
        function obj = updateData(obj)
            rndVals = cellfun(@(x) x*(rand(1)+0.5),obj.currentdata.returnColumn(3),'un',0);
            obj.currentdata.setColumn(3,transpose(rndVals));
        end
    end
end

