function authenticate(mode)

    arguments
        mode (1,1) string {mustBeMember(mode, ["default", "refresh"])} = "default"
    end

    authenticator = ebrains.iam.AuthenticationClient.instance();
    if ~authenticator.hasActiveToken() || mode == "refresh"
        authenticator.fetchToken()
    end
end
