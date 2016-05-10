%Uncomment below line to test using local data.
%Localtest.m
%Uncomment below line to test using the network.
NetworkTest

i = 1;

while true
    %Receive the packet
    received_data = step(receiver);
    %If there is a packet, print it.
    if ~isempty(received_data)
      bytesReceived = length(received_data);
      deserialized_data = data_deserialize(received_data);
      fprintf('Packet: %d\n', i);
      %fprintf('Bytes received: %d\n', bytesReceived);
      %'I have received stuff'
      i = i+1;
    end
    pause(0.001)
   

end
