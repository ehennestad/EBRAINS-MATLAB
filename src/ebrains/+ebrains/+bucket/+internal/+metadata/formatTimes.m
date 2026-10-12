function texts = formatTimes(times)
% formatTimes - Times as the .ebrains files write them, such as "2024-01-02T03:04:05Z"
%
%   An unknown time (NaT) gives "".

    arguments
        times datetime
    end

    times.TimeZone = "UTC";
    texts = string(times, "yyyy-MM-dd'T'HH:mm:ss'Z'");
    texts(ismissing(texts)) = "";
end
