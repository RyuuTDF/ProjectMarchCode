classdef NetworkEnv < Env
	%NETWORKENV Setup the environment for network usage of data.
	% Setup the environment for network usage of data

	properties
        sender
        receiver
    end

	methods
        % Function: NetworkEnv
        % Functionality: Constructs the Network Environment
        function obj = NetworkEnv()
            %Initialize sender and receiver.
            obj.sender = dsp.UDPSender('RemoteIPAddress','192.168.21.1','RemoteIPPort', 25001);
            obj.receiver = dsp.UDPReceiver('RemoteIPAddress', '0.0.0.0','MaximumMessageLength',65507);
            
            obj.referenceChecksum = 0;
            obj.simulationTime = 0;
        end
        
        
        % Function: updateData
        % Functionality: Update the relevant data if a new packet has arrived.
        function obj = updateData(obj)
            packet = step(obj.receiver);
            
            if ~isempty(packet)
                % Check the footer for packet type.
                packetType = packet(end);
                if packetType == 1
                    fprintf('Reference Packet received\n');
                    obj = receivedReference(obj, packet);
                    
                elseif packetType == 2
                    fprintf('Delta Packet received\n');
                    obj = receivedDelta(obj, packet);
                    
                else
                    error('Invalid Packet Type');
                end
                
                %Testing Purposes
                
            end
        end

        
        % Function: receivedReference
        % Functionality: Updates the referencePacket & referenceChecksum      
        function obj = receivedReference(obj, packet)
            obj.referenceData = zlibdecode(packet(1:end-3));
            obj.referenceChecksum = packet(end-2);
            %TODO: Checksum = uint16
            packetData = deserialize(obj.referenceData);
            
            obj.simulationTime = packetData(1);
            
            packetData = packetData(2:end);
            obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetData,5));
        end

        
        % Function: updateData
        % Functionality: Updates the currentData, according to the delta      
        function obj = receivedDelta(obj, packet)
            if packet(end-2) == obj.referenceChecksum
            	decompressed = bitxor(zlibdecode(packet(1:end-3)), obj.referenceData);
                packetData = deserialize(decompressed);
                
                obj.simulationTime = packetData(1);
                
                packetData = packetData(2:end);
                obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetData,5));
            else
                obj = requestNewReference(obj);
            end
        end
        
        % Function: requestNewReference
        % Functionality: Request a new reference packet if checksums don't match.   
        function obj = requestNewReference(obj)
            step(obj.sender, obj.referenceChecksum);
            
            t=timer();
            t.ExecutionMode = 'fixedDelay';
            t.TimerFcn = {@timedOut, obj};
            t.StartDelay = 10;
            t.Period = 10;
            start(t);
  
            newReference = false;
            
            while newReference == false
                packet = step(obj.receiver);
                   
                if ~isempty(packet)
                    % Check the footer for packet type.
                    packetType = packet(end);
                    
                    if packetType == 1
                        stop(t);
                        delete(t);
                        
                        newReference = true;
                        obj = receivedReference(obj, packet);
                        
                        fprintf('Reference Packet received\n');
                    end
                    
                    %Testing Purposes
                    %fprintf('A Packet was received\n');
                end
            end
        end
       
	end
end

