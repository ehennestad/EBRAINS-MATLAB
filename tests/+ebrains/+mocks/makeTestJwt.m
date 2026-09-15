function token = makeTestJwt(claims)
% makeTestJwt - An unsigned JWT with the given claims, for tests
%
%   token = ebrains.mocks.makeTestJwt() returns a token that expires in an
%   hour. token = ebrains.mocks.makeTestJwt(claims) uses the given claims;
%   an exp claim given as posix seconds is kept as it is.

    arguments
        claims (1,1) struct = struct()
    end

    if ~isfield(claims, 'exp')
        claims.exp = round(posixtime(datetime("now", TimeZone="UTC"))) + 3600;
    end

    toBase64Url = @(text) strrep(strrep(erase(matlab.net.base64encode(text), '='), '+', '-'), '/', '_');
    header = struct('alg', 'none', 'typ', 'JWT');
    token = toBase64Url(jsonencode(header)) + "." + toBase64Url(jsonencode(claims)) + ".signature";
end
