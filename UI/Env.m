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
    end

	methods
        function obj = updateData(obj)
        end
    end
end