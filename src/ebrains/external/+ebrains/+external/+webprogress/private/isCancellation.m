function tf = isCancellation(exception)
%isCancellation - Return whether an error comes from a cancelled transfer
%   TF = isCancellation(EXCEPTION) returns true when EXCEPTION, or any of
%   its causes, is the error a FileTransferProgressMonitor raises to stop
%   a cancelled transfer. The HTTP stack passes that error on as the
%   cause of MATLAB:http:UncaughtException.

    tf = exception.identifier == "webprogress:progressMonitor:Cancelled";
    causeIndex = 1;
    while ~tf && causeIndex <= numel(exception.cause)
        tf = isCancellation(exception.cause{causeIndex});
        causeIndex = causeIndex + 1;
    end
end
