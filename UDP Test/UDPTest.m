%Initialize Sender
IPSend = '127.0.0.1';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

%Initialize Receiveroutput
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('RemoteIPAddress', IPReceive,'MaximumMessageLength',65507);

signaldata = cell(100,1);

while true
    for i = 1:100
    signaldata{i, 1} = {sprintf('Signal %d', i), 'Dit is een sensor type', randi(1000), randi(1000), randi(1000), randi(1000)};
    end
    
    serialized_data = hlp_serialize(signaldata);
    
    %Send the packet
    step(sender, serialized_data);
    
    %Receive the packet
    received_data = step(receiver);

    %If there is a packet, print it.
    if ~isempty(received_data)
      deserialized_data = hlp_deserialize(received_data);
      'I have received stuff'
    end
    pause(1)
end
