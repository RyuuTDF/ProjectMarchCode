classdef NetworkEnv < Env
	%NETWORKENV Setup the environment for network usage of data.
	%   Setup the environment for network usage of data

	properties
        receiver
    end

	methods
        % Function: NetworkEnv
        % Functionality: Constructs the Network Environment
        function obj = NetworkEnv()
            obj.receiver = tcpclient('192.168.21.1', 65507);
            %obj.receiver = dsp.UDPReceiver('RemoteIPAddress', '0.0.0.0','MaximumMessageLength',);
             while isempty(obj.currentData)
                obj = updateData(obj);
            end
        end
        
        % Function: updateData
        % Functionality: Update the current data set if a new packet has arrived.
        function obj = updateData(obj)
            packet = step(obj.receiver);
            if ~isempty(packet)
                packetdata = deserialize(packet);
                length(packetdata)
                obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetdata,5));
                
                fprintf('Packet received\n');
            end
        end
    end
end

