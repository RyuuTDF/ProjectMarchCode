classdef SensorDataContainer <  handle
    %SENSORDATACONTAINER Contains the sensor data and methods to convert
    %the data to certain formats
    
    properties
        datamatrix = {};
    end
    
    methods(Static)
        function data = convertLocalData(input,amtCols)
            data = reshape([input{:}],amtCols,[]);
            data = transpose(data);
        end
        
        function data = convertNetworkData(input,amtCols)
            data = reshape(input,amtCols,[]);
            data = transpose(data);
        end
    end
    
    methods
        function matrix = SensorDataContainer(input)
            matrix.datamatrix = input;          
        end
        
        function out = returnColumn(obj,idx)
            out = obj.datamatrix(:,idx);
        end
       function setColumn(obj,idx,data)
            obj.datamatrix(:,idx) = data;
        end
        function out = returnRow(obj,idx)
            out = obj.datamatrix(idx,:);
        end
        function out = returnEntry(obj, idx1,idx2)
            out = obj.datamatrix(idx1,idx2);
        end
    end
    
end

