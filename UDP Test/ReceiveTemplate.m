%Setup the receiver

%Initialize Receiveroutput
IPReceive = '0.0.0.0';
receiver = dsp.UDPReceiver('RemoteIPAddress', IPReceive,'MaximumMessageLength',65507);


%Receive a Packet
%Try to receive a packet
received_data = step(receiver);

%If a packet was received, deserialize the data.
if ~isempty(received_data)
      deserialized_data = data_deserialize(received_data);
end