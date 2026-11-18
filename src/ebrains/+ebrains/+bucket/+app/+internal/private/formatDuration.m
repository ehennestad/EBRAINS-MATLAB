function text = formatDuration(seconds)
% formatDuration - Rounded duration, such as "40 seconds" or "6 minutes"
%
%   Below a minute the duration is rounded to tens of seconds, and is at
%   least "10 seconds". From a minute on it is rounded to whole minutes.
    if seconds < 60
        text = sprintf("%d seconds", max(round(seconds / 10) * 10, 10));
    else
        minutes = round(seconds / 60);
        if minutes == 1
            text = "1 minute";
        else
            text = sprintf("%d minutes", minutes);
        end
    end
end
