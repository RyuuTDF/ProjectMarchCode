classdef Test
    %TEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods(Static)
        function test

        close all;
        %  Create and then hide the UI as it is being constructed.
        f = figure('Visible','off','Position',[360,500,800,800]);

        ha = axes('Units','pixels','Position',[50,60,700,700]);

        % Initialize the UI.
        % Change units to normalized so components resize automatically.
        f.Units = 'normalized';
        ha.Units = 'normalized';
        % Generate the data to plot.
        peaks_data = rand(1,100);

        % Create a plot in the axes.
        current_data = peaks_data;
        plot(current_data);

        % Assign the a name to appear in the window title.
        f.Name = 'Simple GUI';
        pb = uicontrol('Style','checkbox','Callback',@checkbox1_Callback,'Position',[50,50,100,25]);
        align(pb, 'Center','None');

        % Move the window to the center of the screen.
        movegui(f,'center')

        % Make the window visible.
        f.Visible = 'on';
        function checkbox1_Callback(hObject, eventdata, handles)
            while(get(hObject,'Value') == get(hObject,'Max'))
                idx = ceil(100*rand(1));
                current_data(idx) = current_data(idx)*rand(1)*2;
                plot(current_data);
                pause(0.02);
            end
        end

        end
    end
    
    methods
    end
    
end

