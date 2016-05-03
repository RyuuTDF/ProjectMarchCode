<<<<<<< HEAD
%Initialize Sender
IPSend = '127.0.0.1';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

t = 0;
answer = 0;
while true
    answer = sin(t);
    sending = double(t);
    step(sender, sending);

    t = t+1;
    pause(0.5)
=======
%Initialize Sender
IPSend = '131.180.60.212';
sender = dsp.UDPSender('RemoteIPAddress', IPSend);

t = 0;
answer = 0;
while true
    answer = sin(t);
    sending = double(t)
    step(sender, sending);

    t = t+1;
    pause(0.5)
>>>>>>> refs/remotes/origin/master
end