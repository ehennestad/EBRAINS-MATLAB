classdef ListingProgress < handle
% ListingProgress - Show the progress of a bucket listing in a progress dialog
%
%   progress = ebrains.bucket.app.internal.ListingProgress(dialog,
%   nObjects, isWholeBucket) shows the progress of a listing in the
%   uiprogressdlg dialog. nObjects is the object count of the bucket, which
%   is approximate. When the listing is of a folder of the bucket
%   (isWholeBucket false), the count says nothing about how much of the
%   listing is done, so only the number listed is shown.
%
%   progress.update(nListed) shows that nListed objects have been listed,
%   with an estimate of the time left from the rate so far. If the user
%   has pressed Cancel, it throws EBRAINS:Bucket:ListingCancelled, which
%   stops the listing.

    properties (SetAccess = private)
        Dialog
        NumObjects (1,1) double
        IsWholeBucket (1,1) logical
        StartTime (1,1) uint64
    end

    methods
        function progress = ListingProgress(dialog, nObjects, isWholeBucket)
            progress.Dialog = dialog;
            progress.NumObjects = nObjects;
            progress.IsWholeBucket = isWholeBucket;
            progress.StartTime = tic;
        end

        function update(progress, nListed)
            % A click on Cancel reaches the dialog only when MATLAB
            % processes its events, which it does not do on its own
            % between the requests of a listing.
            drawnow
            if progress.Dialog.CancelRequested
                error('EBRAINS:Bucket:ListingCancelled', 'The listing of the bucket was cancelled.')
            end

            if ~progress.IsWholeBucket
                progress.Dialog.Indeterminate = "on";
                progress.Dialog.Message = sprintf( ...
                    "Listing the objects of the folder. %s listed so far. The bucket holds about %s.", ...
                    formatCount(nListed), formatCount(progress.NumObjects));
                return
            end

            progress.Dialog.Indeterminate = "off";
            progress.Dialog.Value = min(nListed / max(progress.NumObjects, 1), 1);
            message = sprintf("Listed %s of about %s objects.", ...
                formatCount(nListed), formatCount(progress.NumObjects));
            if nListed > 0 && nListed < progress.NumObjects
                secondsLeft = toc(progress.StartTime) / nListed * (progress.NumObjects - nListed);
                message = message + " About " + formatDuration(secondsLeft) + " left.";
            end
            progress.Dialog.Message = message;
        end
    end
end

function text = formatCount(count)
% formatCount - Whole number with thousands separators, such as "20,481"
    text = regexprep(sprintf("%d", count), "\d(?=(\d{3})+$)", "$0,");
end

function text = formatDuration(seconds)
% formatDuration - Rounded duration, such as "40 seconds" or "6 minutes"
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
