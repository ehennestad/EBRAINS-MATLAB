function times = parseTimes(texts)
% parseTimes - Read times written as "2024-01-02T03:04:05Z", in UTC
%
%   An empty text gives NaT.

    arguments
        texts string
    end

    times = NaT(size(texts), TimeZone="UTC");
    isGiven = texts ~= "";
    if any(isGiven, "all")
        times(isGiven) = datetime(texts(isGiven), ...
            InputFormat="yyyy-MM-dd'T'HH:mm:ss'Z'", TimeZone="UTC");
    end
end
