classdef FlowType
    %FlowType - OIDC authentication flows supported by the toolbox
    %   FlowType enumerates the OAuth 2.0 grant types that AUTHENTICATE can
    %   use to obtain an EBRAINS access token.
    %
    %   FlowType members:
    %       DeviceFlow            - Interactive login in the browser
    %       ClientCredentialsFlow - Service login with a client id and secret
    %
    %   See also ebrains.authenticate, ebrains.iam.DeviceFlowTokenClient,
    %   ebrains.iam.ClientCredentialsFlowTokenClient

    enumeration
        DeviceFlow
        ClientCredentialsFlow
    end
end
