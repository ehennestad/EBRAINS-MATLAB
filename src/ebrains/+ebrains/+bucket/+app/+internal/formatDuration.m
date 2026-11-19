function text = formatDuration(durationSeconds)
% formatDuration - Rounded duration as text, such as "40 seconds" or "1 hour 10 minutes"
%
%   text = ebrains.bucket.app.internal.formatDuration(durationSeconds)
%   returns the duration as text, rounded to a step that grows with it:
%       "10 seconds" to "50 seconds" - Below 55 seconds, in tens of
%                                      seconds and at least 10.
%       "1 minute" to "59 minutes"   - Below 59.5 minutes, in whole
%                                      minutes.
%       "1 hour", "1 hour 5 minutes" - From there on, in steps of five
%                                      minutes. Whole hours are shown
%                                      without minutes.
%   The duration is rounded before the unit is chosen, so 57 seconds is
%   "1 minute" and 3590 seconds is "1 hour".

    arguments
        durationSeconds (1,1) double {mustBeNonnegative, mustBeFinite}
    end

    secondsPerMinute = 60;
    minutesPerHour = 60;
    secondStep = 10;
    minuteStep = 5;

    roundedSeconds = max(round(durationSeconds / secondStep) * secondStep, secondStep);
    roundedMinutes = round(durationSeconds / secondsPerMinute);

    if roundedSeconds < secondsPerMinute
        text = sprintf("%d seconds", roundedSeconds);
    elseif roundedMinutes < minutesPerHour
        text = withUnit(roundedMinutes, "minute");
    else
        steppedMinutes = round(durationSeconds / secondsPerMinute / minuteStep) * minuteStep;
        wholeHours = floor(steppedMinutes / minutesPerHour);
        minutesPastHour = mod(steppedMinutes, minutesPerHour);
        text = withUnit(wholeHours, "hour");
        if minutesPastHour > 0
            text = text + " " + withUnit(minutesPastHour, "minute");
        end
    end
end

function text = withUnit(count, unit)
% withUnit - Whole number with its unit, plural unless the number is 1, such as "1 hour" or "5 minutes"
    if count == 1
        text = "1 " + unit;
    else
        text = sprintf("%d %ss", count, unit);
    end
end
