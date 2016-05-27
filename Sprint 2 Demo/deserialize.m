function [output] = deserialize(input)
% Adapted from hlp_deserialize.m
% (C) 2010 Christian Kothe & Tim Hutt
% Redistribution and use in source and binary forms, with or without
% modification, are permitted.

    output = {};
    len = uint16(0);
    
    if isempty(input)
        return;
    elseif input(1) == 0;
    	len = input(2) + 5;
    elseif input(1) == 1
    	len = 9;
    elseif input(1) == 133
    	len = 11;
	else
		error('Unsupported data type');
    end
    
    %Typecast needed
    next = uint16(len + 1);
    
	output = [signal_deserialize(input(1:len)); deserialize(input(next:end))];
end

function value = signal_deserialize(input)
% wrap dispatcher
value = deserialize_value(uint8(input(:)),1);

end

% dispatch
function [value,pos] = deserialize_value(input,pos)
switch input(pos)
    case {0,200}
        [value,pos] = deserialize_string(input,pos);
    case 128
        [value,pos] = deserialize_struct(input,pos);
    case {33,34,35,36,37,38,39}
        [value,pos] = deserialize_cell(input,pos);
    case {1,2,3,4,5,6,7,8,9,10}
        [value,pos] = deserialize_scalar(input,pos);
    case 133
        [value,pos] = deserialize_logical(input,pos);
    case {151,152,153}
        [value,pos] = deserialize_handle(input,pos);
    case {17,18,19,20,21,22,23,24,25,26}
        [value,pos] = deserialize_numeric_simple(input,pos);
    case 130
        [value,pos] = deserialize_sparse(input,pos);
    case 131
        [value,pos] = deserialize_complex(input,pos);
    case 132
        [value,pos] = deserialize_char(input,pos);
    case 134
        [value,pos] = deserialize_object(input,pos);
    otherwise
        error('Unknown class');
end
end

% individual scalar
function [value,pos] = deserialize_scalar(input,pos)
    classes = {'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
    sizes = [8,4,1,1,2,2,4,4,8,8];
    sz = sizes(input(pos));
    % Data.
    value = typecast(input(pos+1:pos+sz),classes{input(pos)});
    pos = pos + 1 + sz;
end

% standard string
function [value,pos] = deserialize_string(input,pos)
    if input(pos) == 0
        % horizontal string: tag
        pos = pos + 1;
        % length (uint32)
        nbytes = double(typecast(input(pos:pos+3),'uint32'));
        pos = pos + 4;
        % data (chars)
        value = char(input(pos:pos+nbytes-1))';
        pos = pos + nbytes;
    else
        % proper empty string: tag
        [value,pos] = deal('',pos+1);
    end
end

% general char array
function [value,pos] = deserialize_char(input,pos)
    pos = pos + 1;
    % Number of dims
    ndms = double(input(pos));
    pos = pos + 1;
    % Dimensions
    dms = double(typecast(input(pos:pos+ndms*4-1),'uint32')');
    pos = pos + ndms*4;
    nbytes = prod(dms);
    % Data.
    value = char(input(pos:pos+nbytes-1));
    pos = pos + nbytes;
    value = reshape(value,[dms 1 1]);
end

% general logical array
function [value,pos] = deserialize_logical(input,pos)
    pos = pos + 1;
    % Number of dims
    ndms = double(input(pos));
    pos = pos + 1;
    % Dimensions
    dms = double(typecast(input(pos:pos+ndms*4-1),'uint32')');
    pos = pos + ndms*4;
    nbytes = prod(dms);
    % Data.
    value = logical(input(pos:pos+nbytes-1));
    pos = pos + nbytes;
    value = reshape(value,[dms 1 1]);
end

% simple numerical matrix
function [value,pos] = deserialize_numeric_simple(input,pos)
    classes = {'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
    sizes = [8,4,1,1,2,2,4,4,8,8];
    cls = classes{input(pos)-16};
    sz = sizes(input(pos)-16);
    pos = pos + 1;
    % Number of dims
    ndms = double(input(pos));
    pos = pos + 1;
    % Dimensions
    dms = double(typecast(input(pos:pos+ndms*4-1),'uint32')');
    pos = pos + ndms*4;
    nbytes = prod(dms) * sz;
    % Data.
    value = typecast(input(pos:pos+nbytes-1),cls);
    pos = pos + nbytes;
    value = reshape(value,[dms 1 1]);
end

% complex matrix
function [value,pos] = deserialize_complex(input,pos)
    pos = pos + 1;
    [re,pos] = deserialize_numeric_simple(input,pos);
    [im,pos] = deserialize_numeric_simple(input,pos);
    value = complex(re,im);
end

% sparse matrix
function [value,pos] = deserialize_sparse(input,pos)
    pos = pos + 1;
    % matrix dims
    u = double(typecast(input(pos:pos+7),'uint64'));
    pos = pos + 8;
    value = double(typecast(input(pos:pos+7),'uint64'));
    pos = pos + 8;
    % index vectors
    [i,pos] = deserialize_numeric_simple(input,pos);
    [j,pos] = deserialize_numeric_simple(input,pos);
    if input(pos)
        % real
        pos = pos+1;
        [s,pos] = deserialize_numeric_simple(input,pos);
    else
        % complex
        pos = pos+1;
        [re,pos] = deserialize_numeric_simple(input,pos);
        [im,pos] = deserialize_numeric_simple(input,pos);
        s = complex(re,im);
    end
    value = sparse(i,j,s,u,value);
end
