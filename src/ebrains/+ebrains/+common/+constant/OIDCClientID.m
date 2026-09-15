function oidcClientId = OIDCClientID()
%OIDCClientID - OIDC client id of this toolbox
%   oidcClientId = OIDCClientID() returns the client id that the toolbox
%   authenticates as by default with the EBRAINS identity provider.
%
%   See also ebrains.authenticate, ebrains.iam.DeviceFlowTokenClient

    oidcClientId = "ebrains-services-toolbox-matlab";
end
