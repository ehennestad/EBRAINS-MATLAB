function text = formatBytes(bytes)
% formatBytes - Format a number of bytes with the largest unit that keeps it at or above 1
%
%   text = ebrains.bucket.internal.formatBytes(bytes) returns text such as
%   "512 B" or "1.5 MB", with units of 1024.

    units = ["B", "KB", "MB", "GB", "TB"];
    exponent = min(floor(log(max(bytes, 1)) / log(1024)), numel(units) - 1);
    if exponent == 0
        text = sprintf('%d B', bytes);
    else
        text = sprintf('%.1f %s', bytes / 1024^exponent, units(exponent + 1));
    end
end
