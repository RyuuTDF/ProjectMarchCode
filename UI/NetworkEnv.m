classdef NetworkEnv < Env
	%NETWORKENV Setup the environment for network usage of data.
	% Setup the environment for network usage of data

	properties
        sender
        receiver
        recording
        identifiers
        footer
        idchecked
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
            obj.recording = 0;
            obj.idchecked = 0;
            
            load('SignalProperties.mat');
            
            obj.identifiers = cell2mat(SignalProperties((2:end),1));
            obj.signalproperties = table();
            obj.signalproperties(:,:) = SignalProperties((2:end),:);
            
            obj.signalproperties.Properties.VariableNames = SignalProperties(1,:);
            
             %Check if all identifiers are unique.
            identifiers = obj.signalproperties.Identifier;
            assert(length(unique(identifiers)) == length(identifiers),...
                'The identifiers defined in SignalProperties.mat are not unique.');
       end
        
        
        % Function: updateData
        % Functionality: Update the relevant data if a new packet has arrived.
        function obj = updateData(obj)
            packet = step(obj.receiver);
            obj.hasNewData = false;            
            if ~isempty(packet)
                % Check the footer for packet type.
                % 1 = reference packet
                % 2 = delta packet
                obj.hasNewData = true;
                packetType = packet(end);
                
                if packetType == 1                    
                    obj = receivedReference(obj, packet); 
                elseif packetType == 2
                    obj = receivedDelta(obj, packet);
                else
                    error('Invalid Packet Type');
                end
            end
        end

        
        % Function: receivedReference
        % Functionality: Updates the referencePacket & referenceChecksum      
        function obj = receivedReference(obj, packet)
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
                obj.footer = decompressed(end-12:end);
                decompressed = decompressed(1:end-13);
                
                packetData = deserialize(decompressed);
                
                temp = packetData(1);
                time = temp{1,1};
                
                %Only accept later send delta packets
                if obj.simulationTime < time
                    obj.simulationTime = time;
                    obj.lastDeltaChecksum = packetChecksum;
                
                    packetData = packetData(2:end);
                    obj.hasNewData = true;
                    
                    packetData = transpose(reshape(packetData,2,[]));
                    
                    x = obj.identifiers;
                    y = cell2mat(packetData(:,1));
                    
                    if ~obj.idchecked
                        assert(length(unique(y)) == length(y),...
                            'The identifiers defined in Simulink are not unique.');
                        obj.idchecked = 1;
                    end
                    
                    orderedValues = packetData(Env.mapId2Idx(x,y),2);
                    
                    if(isempty(obj.currentData))
                       load('SignalProperties.mat');
                       datamatrix = [SignalProperties((2:end),2:end) orderedValues];
                       datamatrix(:,[1 2 3 4 5]) = datamatrix(:,[1 2 5 3 4]);
                       
                       datamatrix(:,1) = [datamatrix{:,1}];
                       obj.currentData = datamatrix;
                    else
                        obj.currentData(:,3) = orderedValues;
                    end
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
            sendData = [uint16(1); obj.lastDeltaChecksum];
            step(obj.sender, sendData);
            
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
                    packetType = packet(end);
                    
                    % Check if the packet is the reference packet.
                    if packetType == 1
                        stop(t);
                        delete(t);
                        
                        newReference = true;
                        obj = receivedReference(obj, packet);
                  
                    %If it's a delta packet, only update delta checksum.
                    elseif packetType == 2
                        x = [packet(end-2) packet(end-1)];
                        obj.lastDeltaChecksum = typecast(uint8(x), 'uint16');
                    end
                end
            end
        end
        
        
        % Function: startRecording
        % Functionality: Start packet recording on the Raspberry Pi.   
        function obj = startRecording(obj)
            t = datetime('now');
            p = uint32(posixtime(t));
            p = typecast(p, 'uint16');
            sendData = [uint16(2); p];
            
            step(obj.sender, sendData);
            
            obj.recording = 1;
        end
        
        
        % Function: stopRecording
        % Functionality: Stop packet recording on the Raspberry Pi. 
        function obj = stopRecording(obj)
            sendData = uint16(3);
            step(obj.sender, sendData);
            
            obj.recording = 0;
        end
    end
end

