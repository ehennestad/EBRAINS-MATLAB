classdef DeviceLoginDialog < handle
% DeviceLoginDialog - Message box that follows a device-flow login
%
%   dialog = ebrains.iam.internal.DeviceLoginDialog() opens the box.
%   showRedirecting, showWaiting, and showSuccess move it through the
%   stages of the login; close removes it. DeviceFlowTokenClient creates
%   the dialog through a hook so that a test can replace it with a spy.

    properties (Access = private)
        Figure
    end

    methods
        function obj = DeviceLoginDialog()
            obj.Figure = msgbox("Redirecting to web browser to authenticate...", "Authenticating...");
            obj.enlargeMessageBox()
        end

        function showRedirecting(obj)
            obj.setMessage("Redirecting to web browser to authenticate...")
            pause(1)
        end

        function showWaiting(obj)
            obj.setMessage("Waiting for device login...")
        end

        function showSuccess(obj)
            obj.setMessage("Access token successfully retrieved!")
            pause(1.5)
            obj.close()
        end

        function close(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure)
            end
        end

        function delete(obj)
            obj.close()
        end
    end

    methods (Access = private)
        function setMessage(obj, message)
            if isvalid(obj.Figure)
                obj.Figure.Children(2).Children(1).String = message;
            end
        end

        function enlargeMessageBox(obj)
        % enlargeMessageBox - Widen the box and use a larger font, without the OK button
            hFigure = obj.Figure;
            hFigure.Position = hFigure.Position + [-50, 0, 100, 14];
            hFigure.Children(1).Visible = 'off';
            hFigure.Children(1).FontSize = 14;
            centerHorizontally(hFigure, hFigure.Children(1))
            hFigure.Children(2).Children(1).FontSize = 14;
            hFigure.Children(2).Children(1).Position(2) = hFigure.Children(2).Children(1).Position(2) + 5;
            centerHorizontally(hFigure, hFigure.Children(2).Children(1))
        end
    end
end

function centerHorizontally(hFigure, component)
    figureWidth = hFigure.Position(3);
    componentPosition = component.Position;
    if numel(componentPosition) == 3
        componentPosition(3:4) = component.Extent(3:4);
    end
    component.Position(1) = figureWidth/2 - componentPosition(3)/2;
end
