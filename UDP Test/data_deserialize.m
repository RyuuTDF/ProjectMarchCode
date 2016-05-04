function [output] = data_deserialize(input)
    output = {};
    len = uint16(0);
    
    if isempty(input)
        return;
    elseif input(1) == 0;
    	len = input(2) + 5;
        %disp(sprintf( 'String'))
    elseif input(1) == 1
    	len = 9;
        %disp(sprintf( 'Number'))
    elseif input(1) == 133
    	len = 11;
        %disp(sprintf( 'Logical'))
	else
		error('Unsupported data type');
    end
    
    %Testing Purposes
    %level = level+uint16(len);
    %disp(sprintf( 'Level: %d, Max: %d', level, length(input)))
    
    %Typecast needed
    next = uint16(len + 1);
    
	output = [sensor_deserialize(input(1:len)); data_deserialize(input(next:end))];
end

function v = sensor_deserialize(m)
% wrap dispatcher
v = deserialize_value(uint8(m(:)),1);

end

% dispatch
function [v,pos] = deserialize_value(m,pos)
switch m(pos)
    case {0,200}
        [v,pos] = deserialize_string(m,pos);
    case 128
        [v,pos] = deserialize_struct(m,pos);
    case {33,34,35,36,37,38,39}
        [v,pos] = deserialize_cell(m,pos);
    case {1,2,3,4,5,6,7,8,9,10}
        [v,pos] = deserialize_scalar(m,pos);
    case 133
        [v,pos] = deserialize_logical(m,pos);
    case {151,152,153}
        [v,pos] = deserialize_handle(m,pos);
    case {17,18,19,20,21,22,23,24,25,26}
        [v,pos] = deserialize_numeric_simple(m,pos);
    case 130
        [v,pos] = deserialize_sparse(m,pos);
    case 131
        [v,pos] = deserialize_complex(m,pos);
    case 132
        [v,pos] = deserialize_char(m,pos);
    case 134
        [v,pos] = deserialize_object(m,pos);
    otherwise
        error('Unknown class');
end
end

% individual scalar
function [v,pos] = deserialize_scalar(m,pos)
classes = {'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
sizes = [8,4,1,1,2,2,4,4,8,8];
sz = sizes(m(pos));
% Data.
v = typecast(m(pos+1:pos+sz),classes{m(pos)});
pos = pos + 1 + sz;
end

% standard string
function [v,pos] = deserialize_string(m,pos)
if m(pos) == 0
    % horizontal string: tag
    pos = pos + 1;
    % length (uint32)
    nbytes = double(typecast(m(pos:pos+3),'uint32'));
    pos = pos + 4;
    % data (chars)
    v = char(m(pos:pos+nbytes-1))';
    pos = pos + nbytes;
else
    % proper empty string: tag
    [v,pos] = deal('',pos+1);
end
end

% general char array
function [v,pos] = deserialize_char(m,pos)
pos = pos + 1;
% Number of dims
ndms = double(m(pos));
pos = pos + 1;
% Dimensions
dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
pos = pos + ndms*4;
nbytes = prod(dms);
% Data.
v = char(m(pos:pos+nbytes-1));
pos = pos + nbytes;
v = reshape(v,[dms 1 1]);
end

% general logical array
function [v,pos] = deserialize_logical(m,pos)
pos = pos + 1;
% Number of dims
ndms = double(m(pos));
pos = pos + 1;
% Dimensions
dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
pos = pos + ndms*4;
nbytes = prod(dms);
% Data.
v = logical(m(pos:pos+nbytes-1));
pos = pos + nbytes;
v = reshape(v,[dms 1 1]);
end

% simple numerical matrix
function [v,pos] = deserialize_numeric_simple(m,pos)
classes = {'double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'};
sizes = [8,4,1,1,2,2,4,4,8,8];
cls = classes{m(pos)-16};
sz = sizes(m(pos)-16);
pos = pos + 1;
% Number of dims
ndms = double(m(pos));
pos = pos + 1;
% Dimensions
dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
pos = pos + ndms*4;
nbytes = prod(dms) * sz;
% Data.
v = typecast(m(pos:pos+nbytes-1),cls);
pos = pos + nbytes;
v = reshape(v,[dms 1 1]);
end

% complex matrix
function [v,pos] = deserialize_complex(m,pos)
pos = pos + 1;
[re,pos] = deserialize_numeric_simple(m,pos);
[im,pos] = deserialize_numeric_simple(m,pos);
v = complex(re,im);
end

% sparse matrix
function [v,pos] = deserialize_sparse(m,pos)
pos = pos + 1;
% matrix dims
u = double(typecast(m(pos:pos+7),'uint64'));
pos = pos + 8;
v = double(typecast(m(pos:pos+7),'uint64'));
pos = pos + 8;
% index vectors
[i,pos] = deserialize_numeric_simple(m,pos);
[j,pos] = deserialize_numeric_simple(m,pos);
if m(pos)
    % real
    pos = pos+1;
    [s,pos] = deserialize_numeric_simple(m,pos);
else
    % complex
    pos = pos+1;
    [re,pos] = deserialize_numeric_simple(m,pos);
    [im,pos] = deserialize_numeric_simple(m,pos);
    s = complex(re,im);
end
v = sparse(i,j,s,u,v);
end
