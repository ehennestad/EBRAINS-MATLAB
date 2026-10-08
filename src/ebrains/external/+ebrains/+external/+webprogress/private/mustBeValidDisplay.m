function mustBeValidDisplay(displayName)
%mustBeValidDisplay - Validate that a value is a progress display mode
%   mustBeValidDisplay(displayName) raises an error unless displayName is
%   "Dialog Box", "Command Window" or "None".

    mustBeMember(displayName, {'Dialog Box', 'Command Window', 'None'})
end
