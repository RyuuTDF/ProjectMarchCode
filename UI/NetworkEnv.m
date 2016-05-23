classdef NetworkEnv < Env
	%NETWORKENV Setup the environment for network usage of data.
	%   Setup the environment for network usage of data

	properties
        sender
        receiver
    end

	methods
        % Function: NetworkEnv
        % Functionality: Constructs the Network Environment
        function obj = NetworkEnv()
            %Send for reference packet.
            obj.sender = dsp.UDPSender('192.168.21.1',25001);
            % dataSent = 'Maak de data hier aan'
            % step(obj.sender, dataSent); <- Verstuurd de data
            
            %Receive the first packet
            obj.receiver = dsp.UDPReceiver('RemoteIPAddress', '0.0.0.0','MaximumMessageLength',65507);
            
            %Bouw onderstaande om naar iets dat alles behalve reference paccket negeert.           
            while isempty(obj.currentData)
                obj = updateData(obj);
            end
        end
        
        % Function: updateData
        % Functionality: Update the current data set if a new packet has arrived.
        function obj = updateData(obj)
            %TO DO: Ombouwen dat deze de delta ondersteund.
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

