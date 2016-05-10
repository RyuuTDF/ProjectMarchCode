%Initialize Receiveroutput
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('RemoteIPAddress', IPReceive,'MaximumMessageLength',65507);
bytesReceived = 0;

%Testing Purposes
i = 1;

while true
    %Receive the packet
    received_data = step(receiver);
    %If there is a packet, deserialize it.
    if ~isempty(received_data)
      bytesReceived = length(received_data);
      deserialized_data = data_deserialize(received_data);
      
      %Testing Purposes
      fprintf('Packet: %d\n', i);
      i = i+1;
    end
    pause(0.001)
   

end
  
