function tf = isCancelRequested(cancelRequestedFcn)
%isCancelRequested - Return whether CancelRequestedFcn asks the transfer to stop
%   TF = isCancelRequested(FCN) calls FCN with no inputs and returns its
%   result as a logical scalar. TF is false when FCN is empty. A result
%   that is not a logical or numeric scalar raises an error, because it
%   cannot say whether to stop.

    tf = false;
    if isempty(cancelRequestedFcn)
        return
    end

    result = cancelRequestedFcn();
    if ~(isscalar(result) && (islogical(result) || (isnumeric(result) && ~isnan(result))))
        error("webprogress:validators:InvalidCancelRequestedResult", ...
            "CancelRequestedFcn must return true or false, but it returned a value " + ...
            "of class %s and size %s. Change the function to return a logical scalar.", ...
            class(result), mat2str(size(result)))
    end
    tf = logical(result);
end
