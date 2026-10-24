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

    % The fixtures of virtual buckets, of the Windows-drive rule and of the
    % files of interrupted transfers are on open branches of the package
    % (pull requests 15 to 24, whose top is recheck-selected-files-before-
    % acting, and claude/ebrains-bucket-sync-matlab-l301my on top of it)
    % until they are merged, so the pin is a commit of that branch rather
    % than a release tag.
    sourceUri = "https://github.com/ehennestad/ebrains-bucket-sync@222a789b2fd347b0108119097ab7e5982c0b133e";
    sourceFolder = "spec/fixtures";
    targetFolder = "tests/fixtures/sync-spec";

    matbox.tasks.vendorPackage(projectRootDirectory, sourceUri, sourceFolder, targetFolder);
end
