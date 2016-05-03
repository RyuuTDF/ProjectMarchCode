%Initialize Sender
IPSend = '127.0.0.1';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

signaldata = cell(100,1);

while true
    for i = 1:100
    signaldata{i, 1} = {sprintf('Signal %d', i), 'Dit is een sensor type', randi(1000), randi(1000), randi(1000), randi(1000)};
    end
    
    serialized_data = hlp_serialize(signaldata);
    
    %Send the packet
    step(sender, serialized_data);
    
    pause(0.5)
end