% Function: timedOut
% Functionality: Resend request for new reference packet.
function timedOut(~, ~, obj)
	step(obj.sender, obj.referenceChecksum);
	fprintf('TIMEOUT!\n');
end

