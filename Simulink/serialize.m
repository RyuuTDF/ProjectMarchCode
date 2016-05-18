function serialize(block)
setup(block);
end

function setup(block)
    block.NumInputPorts = 1;
    block.NumOutputPorts = 1;

    block.SetPreCompInpPortInfoToDynamic;
    block.SetPreCompOutPortInfoToDynamic;

    % Register parameters. In order:
    % 1. Label
    % 2. Type
    % 3. Min
    % 4. Max
    block.NumDialogPrms = 4;
    block.DialogPrmsTunable = {'Nontunable','Nontunable','Nontunable','Nontunable'};    

    block.InputPort(1).DatatypeID  = -1;  % inherit from EtherCAT block
    block.InputPort(1).Complexity  = 'Real';
    block.InputPort(1).Dimensions = 1;

    la = signal_serialize(block.DialogPrm(1).Data);

    % Override output port properties
    block.OutputPort(1).DatatypeID  = 3; % serialized uint8 array
    block.OutputPort(1).Complexity  = 'Real';
    block.OutputPort(1).Dimensions = [length(la)+36 1];

    block.SampleTimes = [0.02 0];
    block.SetAccelRunOnTLC(false);
    
    block.RegBlockMethod('Outputs', @Outputs);
    %Initialize the constant parameters
    block.RegBlockMethod('PostPropagationSetup', @DoPostPropSetup); 
    %Assign the constant parameters
    block.RegBlockMethod('Start', @Start);
    
end

function Outputs(block)
    value = block.InputPort(1).Data;
    value_ser = signal_serialize(value);

    output = [
        block.Dwork(1).Data;
        block.Dwork(2).Data;
        value_ser;
        block.Dwork(3).Data;
        block.Dwork(4).Data;
        ];
    
    block.OutputPort(1).Data = output;
end

function DoPostPropSetup(block)
    ser_label = signal_serialize(block.DialogPrm(1).Data);
    
    block.NumDworks                = 4;
    
    block.Dwork(1).Name            = 'ser_label'; 
    block.Dwork(1).DatatypeID      = 3;
    block.Dwork(1).Dimensions      = length(ser_label);
    block.Dwork(1).Complexity      = 'Real';

    block.Dwork(2).Name            = 'ser_type'; 
    block.Dwork(2).DatatypeID      = 3;
    block.Dwork(2).Dimensions      = 9;
    block.Dwork(2).Complexity      = 'Real';
    
    block.Dwork(3).Name            = 'ser_minimum'; 
    block.Dwork(3).DatatypeID      = 3;
    block.Dwork(3).Dimensions      = 9;
    block.Dwork(3).Complexity      = 'Real';
    
    block.Dwork(4).Name            = 'ser_maximum'; 
    block.Dwork(4).DatatypeID      = 3;
    block.Dwork(4).Dimensions      = 9;
    block.Dwork(4).Complexity      = 'Real';
end

function Start(block)
    block.Dwork(1).Data = signal_serialize(block.DialogPrm(1).Data);
    block.Dwork(2).Data = signal_serialize(block.DialogPrm(2).Data); 
    block.Dwork(3).Data = signal_serialize(block.DialogPrm(3).Data);
    block.Dwork(4).Data = signal_serialize(block.DialogPrm(4).Data); 
end

function m = signal_serialize(v)
    % dispatch according to type
    if isnumeric(v) 
        m = serialize_numeric(v);
    elseif ischar(v)
        m = serialize_string(v);
    elseif islogical(v)
        m = serialize_logical(v);
	else
		error('Unsupported data type');
    end
end

% single scalar
function m = serialize_scalar(v)
    % Data type & data
    m = [class2tag(class(v)); typecast(v,'uint8').'];
end

% char arrays
function m = serialize_string(v)
    if size(v,1) == 1
        % horizontal string: Type, Length, and Data
        m = [uint8(0); typecast(uint32(length(v)),'uint8').'; uint8(v(:))];
    elseif sum(size(v)) == 0
        % '': special encoding
        m = uint8(200);
    else
        % general char array: Tag & Number of dimensions, Dimensions, Data
        m = [uint8(132); ndims(v); typecast(uint32(size(v)),'uint8').'; uint8(v(:))];
    end
end

% logical arrays
function m = serialize_logical(v)
    % Tag & Number of dimensions, Dimensions, Data
    m = [uint8(133); ndims(v); typecast(uint32(size(v)),'uint8').'; uint8(v(:))];
end

% non-complex and non-sparse numerical matrix
function m = serialize_numeric_simple(v)
    % Tag & Number of dimensions, Dimensions, Data
    m = [16+class2tag(class(v)); ndims(v); typecast(uint32(size(v)),'uint8').'; typecast(v(:).','uint8').'];
end

% Numeric Matrix: can be real/complex, sparse/full, scalar
function m = serialize_numeric(v)
    if issparse(v)
        % Data Type & Dimensions
        m = [uint8(130); typecast(uint64(size(v,1)), 'uint8').'; typecast(uint64(size(v,2)), 'uint8').']; % vectorize
        % Index vectors
        [i,j,s] = find(v);        
        % Real/Complex
        if isreal(v)
            m = [m; serialize_numeric_simple(i); serialize_numeric_simple(j); 1; serialize_numeric_simple(s)];
        else
            m = [m; serialize_numeric_simple(i); serialize_numeric_simple(j); 0; serialize_numeric_simple(real(s)); serialize_numeric_simple(imag(s))];
        end
    elseif ~isreal(v)
        % Data type & contents
        m = [uint8(131); serialize_numeric_simple(real(v)); serialize_numeric_simple(imag(v))];
    elseif isscalar(v)
        % Scalar
        m = serialize_scalar(v);
    else
        % Simple matrix
        m = serialize_numeric_simple(v);
    end
end

% *container* class to byte
function b = class2tag(cls)
	switch cls
		case 'string'
            b = uint8(0);
		case 'double'
			b = uint8(1);
		case 'single'
			b = uint8(2);
		case 'int8'
			b = uint8(3);
		case 'uint8'
			b = uint8(4);
		case 'int16'
			b = uint8(5);
		case 'uint16'
			b = uint8(6);
		case 'int32'
			b = uint8(7);
		case 'uint32'
			b = uint8(8);
		case 'int64'
			b = uint8(9);
		case 'uint64'
			b = uint8(10);
		otherwise
			error('Unknown class');
    end
end