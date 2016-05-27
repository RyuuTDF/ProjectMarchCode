% Function: timedOut
% Functionality: Resend request for new reference packet.
function timedOut(~, ~, obj)
	step(obj.sender, obj.lastDeltaChecksum);
	
    %Testing Purposes
    fprintf('TIMEOUT!\n');
end

