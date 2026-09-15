classdef SpyLoginDialog < handle
    % SpyLoginDialog - Records the stages a device-flow login goes through
    %
    % Stands in for ebrains.iam.internal.DeviceLoginDialog, so a test can
    % check the sequence of stages without a figure.

    properties
        Calls string = string.empty(1, 0)
    end

    methods
        function showRedirecting(obj)
            obj.Calls(end+1) = "showRedirecting";
        end

        function showWaiting(obj)
            obj.Calls(end+1) = "showWaiting";
        end

        function showSuccess(obj)
            obj.Calls(end+1) = "showSuccess";
        end

        function close(obj)
            obj.Calls(end+1) = "close";
        end
    end
end
