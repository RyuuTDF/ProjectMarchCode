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
            obj.sender = dsp.UDPSender('RemoteIPAddress','192.168.20.1','RemoteIPPort', 25001);
            obj.receiver = dsp.UDPReceiver('RemoteIPAddress', '0.0.0.0','MaximumMessageLength',65507);
            
            %Initialize the values.
            obj.referenceChecksum = 0;
            obj.lastDeltaChecksum = 0;
            obj.simulationTime = 0;
            
        end
        
        
        % Function: updateData
        % Functionality: Update the relevant data if a new packet has arrived.
        function obj = updateData(obj)
            packet = step(obj.receiver);
            
            if ~isempty(packet)
                % Check the footer for packet type.
                % 1 = reference packet
                % 2 = delta packet
                packetType = packet(end);
                if packetType == 1
                    %Testing Purposes
                    fprintf('Reference Packet received\n');
                    
                    obj = receivedReference(obj, packet); 
                    
                elseif packetType == 2
                    %Testing Purposes
                    %fprintf('Delta Packet received\n');
                    obj = receivedDelta(obj, packet);
                   
                else
                    error('Invalid Packet Type');
                end
            end
        end

        
        % Function: receivedReference
        % Functionality: Updates the referencePacket & referenceChecksum      
        function obj = receivedReference(obj, packet)
            %Update the reference data.
            obj.referenceData = zlibdecode(packet(1:end-3));
            x = [packet(end-2) packet(end-1)];
            obj.referenceChecksum = typecast(uint8(x), 'uint16');
        end

        
        % Function: updateData
        % Functionality: Updates the currentData, according to the delta      
        function obj = receivedDelta(obj, packet)
            x = [packet(end-2) packet(end-1)];
            packetChecksum = typecast(uint8(x), 'uint16');
          
            %Check if the GUI has the correct reference packet
            if packetChecksum == obj.referenceChecksum
            	%Decompress and deserialize the data.
                decompressed = bitxor(zlibdecode(packet(1:end-3)), obj.referenceData);
                packetData = deserialize(decompressed);
                
                temp = packetData(1);
                time = temp{1,1};
                
                %Only accept later send delta packets
                if obj.simulationTime < time
                    obj.simulationTime = time;
                    obj.lastDeltaChecksum = packetChecksum;
                
                    packetData = packetData(2:end);
                    obj.currentData = SensorDataContainer(SensorDataContainer.convertNetworkData(packetData,5));
                end
                
            else
                %Otherwise ask for new reference packet
                obj.lastDeltaChecksum = packetChecksum;
                obj = requestNewReference(obj);
            end
        end
        
        % Function: requestNewReference
        % Functionality: Request a new reference packet if checksums don't match.   
        function obj = requestNewReference(obj)
            step(obj.sender, obj.lastDeltaChecksum);
            
            %Start the timer in case the referencepacket gets dropped.
            t=timer();
            t.ExecutionMode = 'fixedDelay';
            t.TimerFcn = {@timedOut, obj};
            t.StartDelay = 10;
            t.Period = 10;
            start(t);
  
            newReference = false;
            
            while ~newReference
                packet = step(obj.receiver);
                   
                if ~isempty(packet)
                    % Check if the packet is the reference packet.
                    packetType = packet(end);
                    
                    if packetType == 1
                        stop(t);
                        delete(t);
                        
                        newReference = true;
                        obj = receivedReference(obj, packet);
                        
                        %Testing Purposes
                        %fprintf('Reference Packet received\n');
                    
                    %Only update delta checksum if it's a delta packet.
                    elseif packetType == 2
                        x = [packet(end-2) packet(end-1)];
                        obj.lastDeltaChecksum = typecast(uint8(x), 'uint16');
                    end
                    
                    %Testing Purposes
                    %fprintf('A Packet was received\n');
                end
            end
        end
       
	end
end

