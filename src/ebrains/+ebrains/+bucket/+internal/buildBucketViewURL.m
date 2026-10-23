function url = buildBucketViewURL(bucketName)
% buildBucketViewURL - Build the address of the page of a bucket in the Collaboratory
%
%   Syntax:
%       url = ebrains.bucket.internal.buildBucketViewURL(bucketName)
%       returns the address of the page that shows the bucket in the
%       Collaboratory, under Collabs on the EBRAINS wiki.
%
%   A collab bucket has the name of its collab, and its page is a page of
%   the collab. A dataset bucket, named d-<uuid>, has a page under that
%   name as well.
%
%   Input Arguments
%       bucketName : Name of the bucket
%
%   Output Arguments
%       url : Address of the page, with the name of the bucket
%             percent-encoded
%
%   See also ebrains.common.constant.CollabBaseUrl,
%   ebrains.kg.internal.buildInstanceViewURL

    arguments
        bucketName (1,1) string {mustBeNonzeroLengthText}
    end

    % The name is one segment of the path, so a character that the path
    % reserves, such as "/", is encoded with it.
    uri = matlab.net.URI(ebrains.common.constant.CollabBaseUrl());
    uri.Path = ["bin", "view", "Collabs", bucketName, "Bucket"];
    url = string(uri);
end
