%Initialize Sender
IPSend = '145.94.216.230';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

%Initialize Receiver
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('MessageDataType','double','RemoteIPAddress', IPReceive);

t = 0;
answer = 0;

while true
    answer = sin(t);
    sending = answer;
    step(sender, sending);
    received = step(receiver)
    
    bytessent = length(sending);
    bytesreceived = length(received);
    isequal(length(bytessent),length(bytesreceived));

    t = t+1;
    pause(0.5)
end
%test