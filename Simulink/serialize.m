function serialize(block)
    %SERIALIZE Serialize a signal
    % This S-function serializes the data of a input signal and combines it with
    % the properties of the signal (put in via GUI), the properties being:
    % 1. Label
    % 2. Type
    % 3. Minimum Safe Value
    % 4. Maximum Safe Value
    % The resulting array can be send through the rest of the Simulink model.

    
    % The setup method is used to setup the basic attributes of the S-function.
    % Do not add any other call to the main body of the function.  
    setup(block);
end

% Function: setup
% Functionality: Sets up the block's basic characteristics such as:
%   - Input ports
%   - Output ports
%   - Dialog parameters
%	- Options
function setup(block)
    %Define the amount and type of ports.
    block.NumInputPorts = 1;
    block.NumOutputPorts = 1;
    
    block.SetPreCompInpPortInfoToDynamic;
    block.SetPreCompOutPortInfoToDynamic;

    % Register parameters. In order:
    % 1. Label
    % 2. Type
    % 3. Minimum Safe Value
    % 4. Maximum Safe Value
    block.NumDialogPrms = 4;
    block.DialogPrmsTunable = {'Nontunable','Nontunable','Nontunable','Nontunable'};    

    %Serialize the label to get it's serialized length.
    label_ser_length = length(signal_serialize(block.DialogPrm(1).Data));
    
    %Setup the input port.
    block.InputPort(1).DatatypeID  = -1;  % inherit from EtherCAT block
    block.InputPort(1).Complexity  = 'Real'; %real
    block.InputPort(1).ouDimensions = 1;

    %Setup the output port.
    block.OutputPort(1).DatatypeID  = 3; % serialized uint8 array
    block.OutputPort(1).Complexity  = 'Real'; %real
    block.OutputPort(1).Dimensions = [label_ser_length+36 1]; %Length label + 4x numeric

    %Setup the sample time.
    block.SampleTimes = [0.02 0];
    block.SetAccelRunOnTLC(false);
    
    % Register the block's functions.
    block.RegBlockMethod('Outputs', @Outputs);
    block.RegBlockMethod('PostPropagationSetup', @DoPostPropSetup); 
    block.RegBlockMethod('Start', @Start);
    
end

% Function: Outputs
% Functionality: Generates the block outputs during a simulation step.
function Outputs(block)
    %Get the signal value and serialize it.
    value = block.InputPort(1).Data;
    value_ser = signal_serialize(value);

    %Concatenate and output the serialized array.
    output = [
        block.Dwork(1).Data;
        block.Dwork(2).Data;
        value_ser;
        block.Dwork(3).Data;
        block.Dwork(4).Data;
        ];
    
    block.OutputPort(1).Data = output;
end

% Function: DoPostPropSetup
% Functionality: Sets up the work areas and the state variables.
function DoPostPropSetup(block)
    % Serialize the label to determine it's length.
    ser_label = signal_serialize(block.DialogPrm(1).Data);
    
    % Define the amount of constant parameters.
    % 1. Label
    % 2. Type
    % 3. Minimum Safe Value
    % 4. Maximum Safe Value
    block.NumDworks                = 4;
    
    block.Dwork(1).Name            = 'ser_label'; 
    block.Dwork(1).DatatypeID      = 3; %uint8
    block.Dwork(1).Dimensions      = length(ser_label); 
    block.Dwork(1).Complexity      = 'Real'; %real

    block.Dwork(2).Name            = 'ser_type'; 
    block.Dwork(2).DatatypeID      = 3; %uint8
    block.Dwork(2).Dimensions      = 9;
    block.Dwork(2).Complexity      = 'Real';
    
    block.Dwork(3).Name            = 'ser_minimum'; 
    block.Dwork(3).DatatypeID      = 3; %uint8
    block.Dwork(3).Dimensions      = 9;
    block.Dwork(3).Complexity      = 'Real';
    
    block.Dwork(4).Name            = 'ser_maximum'; 
    block.Dwork(4).DatatypeID      = 3; %uint8
    block.Dwork(4).Dimensions      = 9;
    block.Dwork(4).Complexity      = 'Real';
end

% Function: Start
% Functionality: Initializes the work areas and the state variables values.
function Start(block)
    % 1. Label
    % 2. Type
    % 3. Minimum Safe Value
    % 4. Maximum Safe Value
    % These parameters are constant and only need to be serialized once.
    block.Dwork(1).Data = signal_serialize(block.DialogPrm(1).Data);
    block.Dwork(2).Data = signal_serialize(block.DialogPrm(2).Data); 
    block.Dwork(3).Data = signal_serialize(block.DialogPrm(3).Data);
    block.Dwork(4).Data = signal_serialize(block.DialogPrm(4).Data); 
end

% Function: signal_serialize
% Functionality: Returns a uint8 array based on the input value.
% 
% Notes: The returned array can be used as input of signalDeserialize to 
%   retrieve the original value.
function output = signal_serialize(value)
% Adapted from hlp_serialize.m
% (C) 2010 Christian Kothe & Tim Hutt
% Redistribution and use in source and binary forms, with or without
% modification, are permitted.

    % Dispatch according to type
    if isnumeric(value) 
        output = serialize_numeric(value);
    elseif ischar(value)
        output = serialize_string(value);
    elseif islogical(value)
        output = serialize_logical(value);
	else
		error('Unsupported data type');
    end
end

% Single scalar
function out = serialize_scalar(value)
    % Data type & data
    out = [class2tag(class(value)); typecast(value,'uint8').'];
end

% Char arrays
function output = serialize_string(value)
    if size(value,1) == 1
        % horizontal string: Type, Length, and Data
        output = [uint8(0); typecast(uint32(length(value)),'uint8').'; uint8(value(:))];
    elseif sum(size(value)) == 0
        % '': special encoding
        output = uint8(200);
    else
        % general char array: Tag & Number of dimensions, Dimensions, Data
        output = [uint8(132); ndims(value); typecast(uint32(size(value)),'uint8').'; uint8(value(:))];
    end
end

% Logical arrays
function output = serialize_logical(value)
    % Tag & Number of dimensions, Dimensions, Data
    output = [uint8(133); ndims(value); typecast(uint32(size(value)),'uint8').'; uint8(value(:))];
end

% Non-complex and non-sparse numerical matrix
function output = serialize_numeric_simple(value)
    % Tag & Number of dimensions, Dimensions, Data
    output = [16+class2tag(class(value)); ndims(value); typecast(uint32(size(value)),'uint8').'; typecast(value(:).','uint8').'];
end

% Numeric Matrix: can be real/complex, sparse/full, scalar
function output = serialize_numeric(value)
    if issparse(value)
        % Data Type & Dimensions
        output = [uint8(130); typecast(uint64(size(value,1)), 'uint8').'; typecast(uint64(size(value,2)), 'uint8').']; % vectorize
        % Index vectors
        [i,j,s] = find(value);        
        % Real/Complex
        if isreal(value)
            output = [output; serialize_numeric_simple(i); serialize_numeric_simple(j); 1; serialize_numeric_simple(s)];
        else
            output = [output; serialize_numeric_simple(i); serialize_numeric_simple(j); 0; serialize_numeric_simple(real(s)); serialize_numeric_simple(imag(s))];
        end
    elseif ~isreal(value)
        % Data type & contents
        output = [uint8(131); serialize_numeric_simple(real(value)); serialize_numeric_simple(imag(value))];
    elseif isscalar(value)
        % Scalar
        output = serialize_scalar(value);
    else
        % Simple matrix
        output = serialize_numeric_simple(value);
    end
end

% *container* class to byte
function classtag = class2tag(cls)
	switch cls
		case 'string'
            classtag = uint8(0);
		case 'double'
			classtag = uint8(1);
		case 'single'
			classtag = uint8(2);
		case 'int8'
			classtag = uint8(3);
		case 'uint8'
			classtag = uint8(4);
		case 'int16'
			classtag = uint8(5);
		case 'uint16'
			classtag = uint8(6);
		case 'int32'
			classtag = uint8(7);
		case 'uint32'
			classtag = uint8(8);
		case 'int64'
			classtag = uint8(9);
		case 'uint64'
			classtag = uint8(10);
		otherwise
			error('Unknown class');
    end
end