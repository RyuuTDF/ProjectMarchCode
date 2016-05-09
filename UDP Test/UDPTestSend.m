%Initialize Sender
IPSend = '127.0.0.1';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

n=0;

while 1
    packetstream = uint8([]);
    
    for i = 1:100
    lab = sprintf('Test %d', i);
    typ = 'Testsensor';
    val = randi(1000);
    mini = randi(1000);
    maxi = randi(1000);
    output = data_serialize(lab, typ, val, mini, maxi);
    packetstream = [packetstream; output];
    end
    
    %Send the packet
    step(sender, packetstream);
    sprintf('Packet %d', n)
    n = n+1;
    pause(1)
end