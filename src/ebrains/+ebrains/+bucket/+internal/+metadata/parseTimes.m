function times = parseTimes(texts)
% parseTimes - Read times written as "2024-01-02T03:04:05Z", in UTC
%
%   times = ebrains.bucket.internal.metadata.parseTimes(texts) returns a
%   datetime array of the size of texts, in UTC. An empty text gives NaT,
%   and so does a text that datetime cannot read in the form
%   yyyy-MM-ddTHH:mm:ssZ, whatever the other texts are.
%
%   See also ebrains.bucket.internal.metadata.formatTimes,
%   ebrains.bucket.internal.metadata.isTimeText

    arguments
        texts string
    end

    inputFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'";
    times = NaT(size(texts), TimeZone="UTC");
    isGiven = texts ~= "";
    if ~any(isGiven, "all")
        return
    end

    try
        times(isGiven) = datetime(texts(isGiven), InputFormat=inputFormat, TimeZone="UTC");
    catch
        % datetime gives NaT for a text it cannot read only when it reads
        % some other text of the array, and errors when it reads none. So
        % the texts are read one by one, which leaves NaT for each text
        % refused and keeps the others.
        for i = reshape(find(isGiven), 1, [])
            try
                times(i) = datetime(texts(i), InputFormat=inputFormat, TimeZone="UTC");
            catch
                % Left as NaT: the text is not a time in the form.
            end
        end
    end
end
