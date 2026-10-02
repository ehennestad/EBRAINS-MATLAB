classdef SyncProgressObserver < handle
% SyncProgressObserver - Receives the progress of a bucket sync
%
%   ebrains.bucket.internal.runSync calls the methods of an observer as a
%   sync runs, in this order:
%       phaseStarted("listing"), and phaseStarted("checksums") when the
%           sync compares checksums
%       planReady(actions)
%       phaseStarted("copying"), then for each file to copy:
%           fileStarted(i), bytesTransferred(i, ...) while it is copied,
%           and fileFinished(i, status, message)
%       phaseStarted("deleting"), then fileStarted and fileFinished for
%           each file to delete
%       syncFinished(actions), or syncFailed(exception) when an error
%           stops the sync
%   The index i is the row of the file in the actions table. Phases with
%   nothing to do are left out, and a dry run goes from planReady to
%   syncFinished.
%
%   runSync asks isCancelRequested before each file and, through the
%   transfer, while a file is copied. Once it returns true, the file in
%   progress is cancelled and the files not yet copied or deleted are
%   skipped.
%
%   This class ignores every call and never asks to cancel, so it serves
%   as the observer of a sync that nobody watches. A subclass overrides
%   the methods it needs.
%
%   See also ebrains.bucket.internal.SyncProgressWindow,
%   ebrains.bucket.syncToBucket, ebrains.bucket.syncFromBucket

    methods
        function phaseStarted(obj, phase) %#ok<INUSD>
        % phaseStarted - Called when a phase starts: "listing", "checksums", "copying" or "deleting"
        end

        function planReady(obj, actions) %#ok<INUSD>
        % planReady - Called with the plan, the table the sync returns, before anything is changed
        end

        function fileStarted(obj, index) %#ok<INUSD>
        % fileStarted - Called when the file in row index starts to be copied or deleted
        end

        function bytesTransferred(obj, index, transferredBytes, totalBytes) %#ok<INUSD>
        % bytesTransferred - Called while the file in row index is copied
        %   totalBytes is NaN when the size of the transfer is unknown.
        end

        function fileFinished(obj, index, status, message) %#ok<INUSD>
        % fileFinished - Called when the file in row index is done
        %   status is "done", "failed" or "cancelled", and message says
        %   why a file failed or was cancelled.
        end

        function syncFinished(obj, actions) %#ok<INUSD>
        % syncFinished - Called with the table the sync returns, once it is done
        end

        function syncFailed(obj, exception) %#ok<INUSD>
        % syncFailed - Called with the error that stops the sync, before it is raised
        end

        function tf = isCancelRequested(obj) %#ok<MANU>
        % isCancelRequested - Return true to stop the sync
            tf = false;
        end
    end
end
