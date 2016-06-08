% Function: timedOut
% Functionality: Resend request for new reference packet.
function timedOut(~, ~, obj)
    requestData = [uint16(1); obj.lastDeltaChecksum];
    step(obj.sender, requestData);
	
    %Testing Purposes
    fprintf('TIMEOUT!\n');
end

