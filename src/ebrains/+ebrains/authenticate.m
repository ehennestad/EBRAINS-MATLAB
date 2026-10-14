function authenticate(varargin)
%AUTHENTICATE - Log in to EBRAINS (alias of ebrains.login)
%   AUTHENTICATE(...) is the same as ebrains.login(...) and takes the
%   same arguments. Use ebrains.login in new code.
%
%   See also login, logout

    % The arguments are forwarded unchanged so that ebrains.login is the
    % one place that declares and validates them.
    ebrains.login(varargin{:})
end
