classdef FakeProgressDialog < handle
    % FakeProgressDialog - Stand-in for a uiprogressdlg that draws nothing
    %
    % Takes the arguments of uiprogressdlg and keeps them in its properties,
    % where a test reads what the code under test set. It is a handle, as
    % the dialog is, so the code under test can delete it. The figure it
    % is given, as uiprogressdlg is, is not used.

    properties
        Title (1,1) string = ""
        Message (1,1) string = ""
        Indeterminate (1,1) string = "off"
        Cancelable (1,1) string = "off"
        Value (1,1) double = 0
        CancelRequested (1,1) logical = false
    end

    methods
        function dialog = FakeProgressDialog(~, options)
            arguments
                ~
                options.Title (1,1) string = ""
                options.Message (1,1) string = ""
                options.Indeterminate (1,1) string = "off"
                options.Cancelable (1,1) string = "off"
                options.Value (1,1) double = 0
            end
            dialog.Title = options.Title;
            dialog.Message = options.Message;
            dialog.Indeterminate = options.Indeterminate;
            dialog.Cancelable = options.Cancelable;
            dialog.Value = options.Value;
        end
    end
end
