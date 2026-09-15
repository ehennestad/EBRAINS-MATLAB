function sizeWithUnitAsString = getDataSizeLabel(sizeInBytes)
% getDataSizeLabel - Format a byte count with the largest unit that fits
%
%   Syntax:
%       label = ebrains.util.getDataSizeLabel(sizeInBytes) returns the size
%       as text with two decimals and a unit, e.g. '1.50 MB'. Sizes below
%       1000 bytes are given in bytes, and sizes at or above 1e18 bytes in
%       petabytes, the largest unit available.

    arguments
        sizeInBytes (1,1) double {mustBeNonnegative, mustBeFinite}
    end

    sizeUnit = ["bytes", "kB", "MB", "GB", "TB", "PB"];

    % log10(0) is -Inf, and a size beyond the last unit would index past
    % the table, so the scale is clamped to the units that exist.
    unitScale = floor(log10(sizeInBytes) / 3);
    unitScale = min(max(unitScale, 0), numel(sizeUnit) - 1);

    sizeAdjusted = sizeInBytes / 10^(3*unitScale);

    sizeWithUnitAsString = sprintf('%.2f %s', sizeAdjusted, sizeUnit(unitScale+1));
end
