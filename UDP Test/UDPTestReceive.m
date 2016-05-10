%Uncomment below line to test using local data.
%LocalTest
%Uncomment below line to test using the network.
NetworkTest

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
