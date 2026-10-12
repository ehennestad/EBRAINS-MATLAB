function updateSyncSpecFixtures()
% updateSyncSpecFixtures - Replace the copy of the sync contract fixtures with the pinned commit
%
%   updateSyncSpecFixtures() downloads the ebrains-bucket-sync package from
%   GitHub at the commit pinned below and replaces tests/fixtures/sync-spec
%   with its spec/fixtures folder: the fixtures of the sync contract that
%   both the package and the ebrains.bucket.sync functions must pass, which
%   ebrains.test.bucket.SpecConformanceTest runs. The commit that was
%   copied is recorded in the vendorinfo.json file of the copy.
%
%   The copy is replaced as a whole and is not edited by hand. A change to
%   the contract is made in the ebrains-bucket-sync repository, and brought
%   in by moving the pin and running this function again.
%
%   See also matbox.tasks.vendorPackage, updateVendoredPackages

    projectRootDirectory = ebtools.projectdir();

    % The fixtures of virtual buckets are on the virtual-bucket-spec branch
    % of the package (its pull request 16) until it is merged, so the pin
    % is a commit of that branch rather than a release tag.
    sourceUri = "https://github.com/ehennestad/ebrains-bucket-sync@c8d47de22684415c34486c050543d97821282554";
    sourceFolder = "spec/fixtures";
    targetFolder = "tests/fixtures/sync-spec";

    matbox.tasks.vendorPackage(projectRootDirectory, sourceUri, sourceFolder, targetFolder);
end
