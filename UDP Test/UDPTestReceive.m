%Initialize Receiver
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('MessageDataType','double','RemoteIPAddress', IPReceive);

while true
    received = step(receiver)
    pause(0.5)
end