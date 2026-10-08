function plan = planSync(sourceFiles, targetFiles, options)
% planSync - Decide what to copy and delete to make a target match a source
%
%   plan = ebrains.bucket.sync.internal.planSync(sourceFiles, targetFiles)
%   compares two file tables, as ebrains.bucket.sync.internal.makeFileTable
%   describes them, and returns a table with one row per path found on
%   either side, sorted by path, with the variables
%       Path   : Path relative to the synced folder, with "/" separators
%       Action : "copy", "delete" or "none"
%       Reason : Why. For a path of the source:
%                    "new"       - the target does not have it
%                    "size"      - the sizes differ
%                    "newer"     - the source was changed after the target
%                    "checksum"  - the checksums differ
%                    "unchanged" - none of the above
%                For a path only the target has: "extraneous"
%       Bytes  : Size of the source file, or of the target file for a path
%                only the target has
%
%   The function only compares; it reads no file and sends no request, so
%   the checksums the comparison needs must be in the tables already.
%
%   Name-Value Arguments
%       Comparison    : How a file on both sides is judged changed:
%                       "SizeAndTime" - (default) the sizes differ, or the
%                                       source was changed after the target
%                       "Size"        - the sizes differ
%                       "Checksum"    - the sizes or the checksums differ.
%                                       Where a checksum is unknown, the
%                                       file is judged as for "SizeAndTime".
%       Delete        : Whether to delete the target files that the source
%                       does not have. Default is false, which keeps them.
%       TimeTolerance : Difference in modification time that still counts
%                       as the same time. Default is 2 seconds, which covers
%                       the time resolution of FAT file systems and the
%                       fraction of a second the listing times lose.
%       IgnoreCase    : Whether paths that differ only in case name the same
%                       file, as on a file system that ignores case. A file
%                       matched this way is planned under its source path.
%                       Default is false.
%
%   See also ebrains.bucket.sync.toBucket, ebrains.bucket.sync.fromBucket

    arguments
        sourceFiles table
        targetFiles table
        options.Comparison (1,1) string ...
            {mustBeMember(options.Comparison, ["SizeAndTime", "Size", "Checksum"])} = "SizeAndTime"
        options.Delete (1,1) logical = false
        options.TimeTolerance (1,1) duration = seconds(2)
        options.IgnoreCase (1,1) logical = false
    end

    sourceKeys = sourceFiles.Path;
    targetKeys = targetFiles.Path;
    if options.IgnoreCase
        sourceKeys = lower(sourceKeys);
        targetKeys = lower(targetKeys);
    end
    [isInTarget, targetIndex] = ismember(sourceKeys, targetKeys);

    % The variables are taken out of the tables once, since indexing a
    % table row by row is slow for buckets with many objects.
    nSource = height(sourceFiles);
    sourceReason = repmat("new", nSource, 1);
    isCommon = find(isInTarget);
    commonTarget = targetIndex(isCommon);
    sourceReason(isCommon) = compareFiles( ...
        sourceFiles.Bytes(isCommon), targetFiles.Bytes(commonTarget), ...
        sourceFiles.ModifiedTime(isCommon), targetFiles.ModifiedTime(commonTarget), ...
        sourceFiles.Hash(isCommon), targetFiles.Hash(commonTarget), options);
    sourceAction = repmat("copy", nSource, 1);
    sourceAction(sourceReason == "unchanged") = "none";

    extraneousFiles = targetFiles(~ismember(targetKeys, sourceKeys), :);
    nExtraneous = height(extraneousFiles);
    extraneousReason = repmat("extraneous", nExtraneous, 1);
    if options.Delete
        extraneousAction = repmat("delete", nExtraneous, 1);
    else
        extraneousAction = repmat("none", nExtraneous, 1);
    end

    plan = table( ...
        [sourceFiles.Path; extraneousFiles.Path], ...
        [sourceAction; extraneousAction], ...
        [sourceReason; extraneousReason], ...
        [sourceFiles.Bytes; extraneousFiles.Bytes], ...
        'VariableNames', ["Path", "Action", "Reason", "Bytes"]);
    plan = sortrows(plan, "Path");
end

function reason = compareFiles(sourceBytes, targetBytes, sourceTimes, ...
        targetTimes, sourceHashes, targetHashes, options)
% compareFiles - Reason to copy each file the target has, or "unchanged"
%
%   The inputs are columns with one element per file on both sides. The
%   first reason that applies is given: a size difference before a
%   checksum or time difference.

    reason = repmat("unchanged", numel(sourceBytes), 1);
    if isempty(reason)
        return
    end

    isSizeChanged = sourceBytes ~= targetBytes;

    isContentCompared = false(size(reason));
    if options.Comparison == "Checksum"
        isContentCompared = sourceHashes ~= "" & targetHashes ~= "";
    end
    isContentChanged = isContentCompared & sourceHashes ~= targetHashes;

    % A file whose checksum is not known on both sides is judged by time.
    % An unknown time on either side gives a NaN difference, for which the
    % comparison is false: the file is left as it is.
    isTimeCompared = options.Comparison ~= "Size" & ~isContentCompared;
    isNewer = isTimeCompared & (sourceTimes - targetTimes > options.TimeTolerance);

    reason(isNewer) = "newer";
    reason(isContentChanged) = "checksum";
    reason(isSizeChanged) = "size";
end
