env = NetworkEnv();

while isempty(env.currentData)
	env = updateData(env);
end

SignalProperties = cell(41,5);

SignalProperties(1,:) = {'Identifier' 'Label' 'Type' 'Minimum' 'Maximum'};

for i = 2:41
    SignalProperties{i,1} = env.currentData.datamatrix{i-1,1};
    SignalProperties{i,2} = strcat({'Test '}, num2str(env.currentData.datamatrix{i-1,1}));
    SignalProperties{i,3} = 0;
    SignalProperties{i,4} = 0;
    SignalProperties{i,5} = 0;
end