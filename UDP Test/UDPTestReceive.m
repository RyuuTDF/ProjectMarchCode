%Initialize Receiver
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('MessageDataType','double','RemoteIPAddress', IPReceive);

while true
    received = step(receiver);
    if isempty(received) == 0
       received
    end
    pause(0.001)
end