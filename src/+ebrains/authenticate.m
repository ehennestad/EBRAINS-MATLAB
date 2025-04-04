authenticator = ebrains.iam.AuthenticationClient.instance();
if ~authenticator.hasActiveToken()
    authenticator.fetchToken()
end
