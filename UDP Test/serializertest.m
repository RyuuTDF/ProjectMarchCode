packetstream = uint8([]);

for i = 1:100
    lab = sprintf('Test %d', i);
    typ = 'Testsensor';
    val = 65.34;
    mini = 36;
    maxi = true;
    output = data_serialize(lab, typ, val, mini, maxi);
    packetstream = [packetstream; output];
end

%Testpurposes, add level to input argument of data_deserialize
%level = uint16(1);

sensor_test = data_deserialize(output);
packet_test = data_deserialize(packetstream);