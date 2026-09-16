function expiration_time = get_token_expiration(token)
% GET_TOKEN_EXPIRATION - Return token expiration time in local time zone
%
%   The exp claim is checked before it is read, so that a token without a
%   usable one is reported as a malformed token rather than as a missing
%   field of a struct the caller never saw.

    decoded_token = ebrains.internal.decode_jwt(token);

    hasExpiryClaim = isstruct(decoded_token) && isfield(decoded_token, 'exp') ...
        && isnumeric(decoded_token.exp) && isscalar(decoded_token.exp);

    if ~hasExpiryClaim
        error('EBRAINS:IAM:MalformedToken', ...
            ['The access token carries no numeric "exp" claim, so the time ', ...
            'at which it expires cannot be read.'])
    end

    expiration_time = datetime(decoded_token.exp, ...
        'ConvertFrom', 'posixtime', 'TimeZone', 'local');
end
