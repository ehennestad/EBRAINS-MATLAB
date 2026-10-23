function tf = isTimeText(texts)
% isTimeText - Whether each text is a time as the .ebrains files write it, such as "2024-01-02T03:04:05Z"
%
%   tf = ebrains.bucket.internal.metadata.isTimeText(texts) is true for a
%   text in exactly the form yyyy-MM-ddTHH:mm:ssZ that names a date that
%   exists, and false for a fraction of a second, an offset, a missing Z,
%   or a day such as February 30.

    arguments
        texts string
    end

    tf = matches(texts, regexpPattern("\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"));
    if any(tf, "all")
        % A day that does not exist, such as February 30, must not pass.
        % Whether datetime refuses it (NaT, written back as "") or reads
        % it as a day of the next month, the time does not give the text
        % back.
        times = ebrains.bucket.internal.metadata.parseTimes(texts(tf));
        tf(tf) = ebrains.bucket.internal.metadata.formatTimes(times) == texts(tf);
    end
end
