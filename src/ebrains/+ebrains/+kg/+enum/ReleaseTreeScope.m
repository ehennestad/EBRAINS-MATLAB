classdef ReleaseTreeScope
%ReleaseTreeScope - Which instances a release status request covers
%   ReleaseTreeScope enumerates the values accepted by the
%   releaseTreeScope option of getReleaseStatus in InstancesClient.
%
%   ReleaseTreeScope members:
%       TOP_INSTANCE_ONLY        - The instance itself
%       CHILDREN_ONLY            - The instances linked from it
%       CHILDREN_ONLY_RESTRICTED - The linked instances, restricted scope
%
%   See also ebrains.kg.api.InstancesClient

    enumeration
        TOP_INSTANCE_ONLY
        CHILDREN_ONLY
        CHILDREN_ONLY_RESTRICTED
    end
end
