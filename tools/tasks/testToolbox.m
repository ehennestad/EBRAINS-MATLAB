function testToolbox(varargin)
% testToolbox - Run the test suites with coverage of the toolbox's own source files
%
%   The CI workflow calls this instead of the MatBox task so that vendored
%   code listed in tools/.coverageignore is left out of the coverage report,
%   and so that tests tagged "LiveIntegration" are excluded: those call the
%   real EBRAINS APIs and run on a schedule instead; see
%   runLiveIntegrationTests and .github/workflows/run-live-tests.yml.

    projectRootDirectory = ebtools.projectdir();

    matbox.tasks.testToolbox(projectRootDirectory, ...
        varargin{:}, ...
        "ExcludeTags", "LiveIntegration", ...
        "CoverageFileList", ebtools.listSourceFiles());
end
