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

    % The fixtures of the registry of virtual buckets (pull requests 34 and
    % 35 of the package) are on its main branch but not in a release yet,
    % so the pin is the merge commit of pull request 35 rather than a
    % release tag.
    sourceUri = "https://github.com/ehennestad/ebrains-bucket-sync@5e120fb4007e0e83708c70d0bd450ba77eaf6a9a";
    sourceFolder = "spec/fixtures";
    targetFolder = "tests/fixtures/sync-spec";

    matbox.tasks.vendorPackage(projectRootDirectory, sourceUri, sourceFolder, targetFolder);
end
