%Initialize Receiveroutput
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('RemoteIPAddress', IPReceive,'MaximumMessageLength',65507);
bytesReceived = 0;

while true
    %Receive the packet
    received_data = step(receiver);

    %If there is a packet, print it.
    if ~isempty(received_data)
      bytesReceived = length(received_data);
      deserialized_data = data_deserialize(received_data);
      fprintf('Bytes received: %d\n', bytesReceived);
      %'I have received stuff'
    end
    pause(0.5)
   
end
