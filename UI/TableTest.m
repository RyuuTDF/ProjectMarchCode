load('SignalProperties.mat');

properties = table();
properties(:,:) = SignalProperties((2:end),:);

properties.Properties.VariableNames = SignalProperties(1,:);
