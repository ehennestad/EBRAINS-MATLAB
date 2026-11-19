function text = formatBytes(bytes)
% formatBytes - Size in bytes as text with a binary unit
%
%   text = ebrains.bucket.app.internal.formatBytes(bytes) returns the
%   whole number of bytes as text: "512 B" below 1024 bytes, and one
%   decimal with the largest unit of KB, MB, GB and TB that gives a value
%   of at least 1 above, such as "1.5 MB". The units are binary, so 1 KB
%   is 1024 bytes.

    arguments
        bytes (1,1) double {mustBeNonnegative}
    end

    units = ["B", "KB", "MB", "GB", "TB"];
    exponent = min(max(floor(log(max(bytes, 1)) / log(1024)), 0), numel(units) - 1);
    if exponent == 0
        text = sprintf("%d B", bytes);
    else
        text = sprintf("%.1f %s", bytes / 1024^exponent, units(exponent + 1));
    end
end
