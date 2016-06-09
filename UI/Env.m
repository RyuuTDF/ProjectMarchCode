classdef Env
	%ENV Setup the environment.
	% Setup the environment

	properties
        currentData
        referenceData
        referenceChecksum
        lastDeltaChecksum
        simulationTime 
        hasNewData
        signalproperties
    end
    
    methods(Static)
        function arr = mapId2Idx(props,packets)
            [z, arr] = ismember(packets,props);
        end
    end

	methods
        function obj = updateData(obj)
        end
        

    end
end