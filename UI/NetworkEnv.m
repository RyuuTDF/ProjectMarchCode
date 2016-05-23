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
                
                % IF Footer = 1
                    %obj = receivedReference(obj, packet);
                    
                % IF Footer = 2
                    obj = receivedDelta(obj, packet);
               
                % ELSE THROW ERROR WANT INVALID PACKET
                    %error('Invalid Packet Type');
                
                %Testing Purposes
                fprintf('Packet received\n');
            end
        end

        
        % Function: receivedReference
        % Functionality: Updates the referencePacket & referenceChecksum      
        function obj = receivedReference(obj, packet)

        end

        
        % Function: updateData
        % Functionality: Updates the currentData, according to the delta      
        function obj = receivedDelta(obj, packet)
        	packetdata = deserialize(packet);
        	obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetdata,5));
        end
    end
end

