function tf = isDataTimeout(exception)
%isDataTimeout - Return whether an error comes from a transfer that received no data in time
%   TF = isDataTimeout(EXCEPTION) returns true when EXCEPTION is the error
%   the HTTP client raises when a transfer receives no data for
%   HTTPOptions.DataTimeout seconds, whether while waiting for the
%   response header or for the rest of a body.
%
%   The client raises the same identifier when a connection cannot be
%   made within ConnectTimeout, and only its message tells the two
%   apart: each names the HTTPOptions property to raise.

    tf = exception.identifier == "MATLAB:webservices:Timeout" ...
        && contains(exception.message, "DataTimeout");
end
