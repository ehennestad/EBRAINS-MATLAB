function message = downloadFailureReport(failedPaths, failureMessages, nFiles)
% downloadFailureReport - Say which files of a batch could not be downloaded, and why
%
%   message = ebrains.bucket.app.internal.downloadFailureReport(failedPaths, failureMessages, nFiles)
%   returns the text of one alert for the downloads that failed in a batch
%   of nFiles files. Files that failed with the same message are reported
%   together: the message once, followed by the paths of its files. At
%   most 3 messages are reported, with at most 3 paths under each, and the
%   remaining files are counted. For a batch of one file, the text names
%   the file and gives its message.
%
%   Input Arguments
%       failedPaths     : Paths of the files that could not be downloaded
%       failureMessages : Message of the error of each file of failedPaths
%       nFiles          : Number of files in the batch, failed or not
    arguments
        failedPaths (:,1) string {mustBeNonempty}
        failureMessages (:,1) string {mustBeNonempty}
        nFiles (1,1) double {mustBePositive, mustBeInteger}
    end

    maxReasons = 3;
    maxPathsPerReason = 3;
    lineBreak = string(newline);
    paragraphBreak = lineBreak + lineBreak;

    if nFiles == 1
        message = sprintf("""%s"" could not be downloaded.", failedPaths) + paragraphBreak + failureMessages;
        return
    end

    [reasons, ~, reasonIndex] = unique(failureMessages, "stable");
    nReported = min(numel(reasons), maxReasons);
    paragraphs = strings(nReported, 1);
    for i = 1:nReported
        paths = failedPaths(reasonIndex == i);
        nNamed = min(numel(paths), maxPathsPerReason);
        lines = [reasons(i); "- " + paths(1:nNamed)];
        if numel(paths) > nNamed
            lines = [lines; sprintf("- and %d more", numel(paths) - nNamed)]; %#ok<AGROW>
        end
        paragraphs(i) = join(lines, lineBreak, 1);
    end

    nFailed = numel(failedPaths);
    message = sprintf("%d of %d files could not be downloaded.", nFailed, nFiles) + paragraphBreak + ...
        join(paragraphs, paragraphBreak, 1);

    nUnreported = sum(reasonIndex > nReported);
    if nUnreported == 1
        message = message + paragraphBreak + "1 more file could not be downloaded for another reason.";
    elseif nUnreported > 1
        message = message + paragraphBreak + ...
            sprintf("%d more files could not be downloaded for other reasons.", nUnreported);
    end
end
