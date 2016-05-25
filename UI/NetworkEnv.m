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
            
            %BOUW onderstaande om naar iets dat alles behalve reference packet negeert.           
            while isempty(obj.currentData)
                obj = updateData(obj);
            end
        end
        
        
        % Function: updateData
        % Functionality: Update the relevant data if a new packet has arrived.
        function obj = updateData(obj)
            packet = step(obj.receiver);
            
            if ~isempty(packet)
                % CHECK FOOTER FOR ID
                packetType = packet(end);
                if packetType == 1
                    obj = receivedReference(obj, packet);                    
                elseif packetType == 2
                    obj = receivedDelta(obj, packet);               
                else THROW ERROR WANT INVALID PACKET
                    error('Invalid Packet Type');
                end
                
                %Testing Purposes
                fprintf('Packet received\n');
            end
        end

        
        % Function: receivedReference
        % Functionality: Updates the referencePacket & referenceChecksum      
        function obj = receivedReference(obj, packet)
            obj.referenceData = zlibdecode(packet(0:end-3));
            packetData = deserialize(obj.referenceData);
            obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetData,5));
            
        end

        
        % Function: updateData
        % Functionality: Updates the currentData, according to the delta      
        function obj = receivedDelta(obj, packet)
            decompressed = bitxor(zlibdecode(packet(0:end-3)), obj.referenceData);            
        	packetdata = deserialize(decompressed);
        	obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetdata,5));
        end
    end
end

