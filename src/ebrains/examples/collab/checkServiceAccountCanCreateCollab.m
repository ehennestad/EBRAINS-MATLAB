% Check whether a service account can set up a collab in the integration
% environment of EBRAINS: create the collab on wiki-int.ebrains.eu, add a
% user to its team, create its bucket on data-proxy-int.ebrains.eu and
% upload a file to the bucket.
%
% A service account is an OIDC client that authenticates with its client
% id and secret (client credentials flow). Before running the script, set
% the environment variables EBRAINS_INT_CLIENT_ID and
% EBRAINS_INT_CLIENT_SECRET to the credentials of a client registered at
% iam-int.ebrains.eu.
%
% The script works in the integration environment and switches back to the
% environment it started in at the end. A login of that environment is
% kept. The collab and the bucket that the script creates stay on the
% server.

CLAIMS_TO_SHOW = ["azp", "preferred_username", "scope"];

% User that is added to the team of the collab, and the role the user gets
TEAM_USERNAME = "eivind";
TEAM_ROLE = "editor";

% Name the uploaded file gets in the bucket
OBJECT_NAME = "service-account-check.txt";

clientId = string(getenv("EBRAINS_INT_CLIENT_ID"));
clientSecret = string(getenv("EBRAINS_INT_CLIENT_SECRET"));
assert(strlength(clientId) > 0 && strlength(clientSecret) > 0, ...
    "Set the environment variables EBRAINS_INT_CLIENT_ID and EBRAINS_INT_CLIENT_SECRET.")

collabName = "service-account-check-" + string(datetime("now", Format="yyyyMMdd-HHmmss"));
collabTitle = "Service account check";

sourceFile = string(tempname()) + ".txt";
writelines("Uploaded by checkServiceAccountCanCreateCollab.", sourceFile)

previousEnvironment = ebrains.getpref("Environment");
ebrains.useEnvironment("int")

try
    currentStep = "log in";
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

    currentStep = "create a collab";
    collabClient = ebrains.collab.api.CollabsClient();
    collabClient.createCollab(collabName, collabTitle, public=false)
    collabUrl = ebrains.common.constant.CollabBaseUrl() + "/bin/view/Collabs/" + collabName;
    fprintf("Created the collab %s\n", collabUrl)

    currentStep = "add a user to the team of the collab";
    collabClient.addTeamUser(collabName, TEAM_ROLE, TEAM_USERNAME)
    fprintf("Added the user %s to the team as %s\n", TEAM_USERNAME, TEAM_ROLE)

    % The bucket of a collab has the name of the collab.
    currentStep = "create the bucket of the collab";
    bucketClient = ebrains.bucket.api.BucketsClient();
    wasBucketCreated = bucketClient.createBucket(collabName);
    if wasBucketCreated
        fprintf("Created the bucket %s\n", collabName)
    else
        fprintf("The bucket %s existed already\n", collabName)
    end

    currentStep = "upload a file to the bucket";
    ebrains.bucket.uploadFile(collabName, OBJECT_NAME, sourceFile, DisplayMode="Command Window")
    fprintf("Uploaded %s to the bucket\n", OBJECT_NAME)
catch exception
    fprintf("The service account could not %s.\n  %s\n  %s\n", ...
        currentStep, exception.identifier, exception.message)
end

delete(sourceFile)
ebrains.useEnvironment(previousEnvironment)
