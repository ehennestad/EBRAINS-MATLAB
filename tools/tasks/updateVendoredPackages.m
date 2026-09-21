function updateVendoredPackages()
% updateVendoredPackages - Replace the vendored packages with the versions pinned here
%
%   updateVendoredPackages() downloads each package listed below from
%   GitHub and replaces its copy in src/ebrains/external, where the
%   package is part of the namespace ebrains.external. The commit that
%   was copied is recorded in the vendorinfo.json file of the copy.
%
%   The copies are replaced as a whole and are not edited by hand. A
%   change to a vendored package is made in its own repository and
%   brought in by running this function again.
%
%   See also matbox.tasks.vendorPackage

    projectRootDirectory = ebtools.projectdir();

    % webprogress: file transfers with a progress display. toolboxdir and
    % toolboxversion locate the Contents.m file of an installed webprogress
    % toolbox, which the copy does not have.
    sourceUri = "https://github.com/ehennestad/http-progressbar-matlab@v2.0.0";
    sourceFolder = "src/webprogress/+webprogress";
    targetFolder = "src/ebrains/external/+ebrains/+external/+webprogress";
    excludedFiles = ["toolboxdir.m", "toolboxversion.m"];

    matbox.tasks.vendorPackage(projectRootDirectory, ...
        sourceUri, sourceFolder, targetFolder, ExcludeFiles=excludedFiles);
end
