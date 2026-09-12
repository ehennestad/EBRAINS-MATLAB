function bodyText = getResponseBodyText(response)
% getResponseBodyText - Text of a response body, or "" if there is none
%
% Syntax:
%   bodyText = ebrains.common.internal.getResponseBodyText(response)
%   returns the body of an HTTP response as text for use in error messages.
%
% Input Arguments:
%   response - A matlab.net.http.ResponseMessage.
%
% Output Arguments:
%   bodyText - String. Text and raw bodies are returned as they are. A
%              decoded JSON body (a struct) is re-encoded so that the
%              server's explanation is still shown. A response without a
%              body gives "".

    arguments
        response (1,1) matlab.net.http.ResponseMessage
    end

    bodyText = "";

    if isempty(response.Body) || isempty(response.Body.Data)
        return
    end

    % The body is decoded JSON when the request asked for conversion, raw
    % text when it did not, and raw bytes for non-text content types.
    data = response.Body.Data;
    if isa(data, 'uint8')
        data = char(reshape(data, 1, []));
    end

    if ischar(data) || isstring(data)
        bodyText = string(data);
    elseif isstruct(data)
        bodyText = string(jsonencode(data));
    end
end
