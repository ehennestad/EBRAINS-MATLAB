function mustBeFunctionHandleOrEmpty(value)
%mustBeFunctionHandleOrEmpty - Validate that a value is a function handle or empty
%   mustBeFunctionHandleOrEmpty(VALUE) raises an error unless VALUE is
%   empty or a scalar function handle.

    if isempty(value)
        return
    end

    if ~(isscalar(value) && isa(value, 'function_handle'))
        error('webprogress:validators:InvalidFunctionHandle', ...
            'The value must be a function handle or empty.')
    end
end
