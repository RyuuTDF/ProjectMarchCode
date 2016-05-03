<<<<<<< HEAD
%Initialize Sender
IPSend = '145.94.206.194';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

%Initialize Receiver
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('MessageDataType','double','RemoteIPAddress', IPReceive);

t = 0;
answer = 0;
received=[]
while true
    answer = sin(t);
    sending = answer;
    step(sender, sending);
    received = [received,step(receiver)];
    plot(received)
    bytessent = length(sending);
    bytesreceived = length(received);
    isequal(length(bytessent),length(bytesreceived));

    t = t+1;
    pause(0.5)
end
%test
=======
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
>>>>>>> refs/remotes/origin/jens
