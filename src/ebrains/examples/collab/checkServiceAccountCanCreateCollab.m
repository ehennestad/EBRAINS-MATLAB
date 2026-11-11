% Check whether a service account can create a collab in the integration
% environment of EBRAINS (wiki-int.ebrains.eu).
%
% A service account is an OIDC client that authenticates with its client
% id and secret (client credentials flow). Before running the script, set
% the environment variables EBRAINS_INT_CLIENT_ID and
% EBRAINS_INT_CLIENT_SECRET to the credentials of a client registered at
% iam-int.ebrains.eu.
%
% The script works in the integration environment and switches back to the
% environment it started in at the end. A login of that environment is
% kept. A collab that the script creates stays on the server.

CLAIMS_TO_SHOW = ["azp", "preferred_username", "scope"];

clientId = string(getenv("EBRAINS_INT_CLIENT_ID"));
clientSecret = string(getenv("EBRAINS_INT_CLIENT_SECRET"));
assert(strlength(clientId) > 0 && strlength(clientSecret) > 0, ...
    "Set the environment variables EBRAINS_INT_CLIENT_ID and EBRAINS_INT_CLIENT_SECRET.")

collabName = "service-account-check-" + string(datetime("now", Format="yyyyMMdd-HHmmss"));
collabTitle = "Service account check";

previousEnvironment = ebrains.getpref("Environment");
ebrains.useEnvironment("int")

try
    ebrains.login("refresh", OAuthFlow="ClientCredentialsFlow", ...
        OIDCClientID=clientId, OIDCClientSecret=clientSecret)

    % The documentation of the Collaboratory API asks for a token with
    % the scopes clb.wiki.read and/or clb.wiki.write.
    tokenClient = ebrains.iam.ClientCredentialsFlowTokenClient.instance();
    claims = ebrains.internal.decode_jwt(tokenClient.AccessToken);
    fprintf("Claims of the token:\n")
    for claimName = CLAIMS_TO_SHOW(isfield(claims, CLAIMS_TO_SHOW))
        fprintf("  %s: %s\n", claimName, string(claims.(claimName)))
    end

    collabClient = ebrains.collab.api.CollabsClient();
    collabClient.createCollab(collabName, collabTitle, public=false)
    collabClient.

    collabUrl = ebrains.common.constant.CollabBaseUrl() + "/bin/view/Collabs/" + collabName;
    fprintf("The service account created the collab %s\n", collabUrl)
catch exception
    fprintf("The service account could not create a collab.\n  %s\n  %s\n", ...
        exception.identifier, exception.message)
end

ebrains.useEnvironment(previousEnvironment)
