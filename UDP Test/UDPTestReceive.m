<<<<<<< HEAD
<<<<<<< HEAD
%Initialize Receiver
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('MessageDataType','double','RemoteIPAddress', IPReceive);

while true
    received = step(receiver)
    pause(0.5)
=======
%Initialize Receiver
=======
%Initialize Receiveroutput
>>>>>>> refs/remotes/origin/jens
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('RemoteIPAddress', IPReceive,'MaximumMessageLength',65507);

while true
    %Receive the packet
    received_data = step(receiver);

    %If there is a packet, print it.
    if ~isempty(received_data)
      deserialized_data = hlp_deserialize(received_data);
      'I have received stuff'
    end
<<<<<<< HEAD
    pause(0.001)
>>>>>>> refs/remotes/origin/master
end
=======
    pause(0.02)
end
>>>>>>> refs/remotes/origin/jens
