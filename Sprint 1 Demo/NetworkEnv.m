classdef NetworkEnv < Env
	%NETWORKENV Setup the environment for network usage of data.
	%   Setup the environment for network usage of data

	properties
        receiver
    end

	methods
        %Setup the network environment
        function obj = NetworkEnv()
            obj.receiver = dsp.UDPReceiver('RemoteIPAddress', '0.0.0.0','MaximumMessageLength',65507);
             while isempty(obj.currentdata)
                obj = updateData(obj);
            end
        end
        
        %Update the current data set if a new packet has arrived.
        function obj = updateData(obj)
            packet = step(obj.receiver);
            if ~isempty(packet)
                packetdata = data_deserialize(packet);
                obj.currentdata = SensorDataContainer(SensorDataContainer.convertNetworkData(packetdata,5));
                
                fprintf('Packet received\n');
            end
        end
    end
end

