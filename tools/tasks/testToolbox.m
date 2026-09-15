function testToolbox(varargin)
% testToolbox - Run the test suites with coverage of the toolbox's own source files
%
%   The CI workflow calls this instead of the MatBox task so that vendored
%   code listed in tools/.coverageignore is left out of the coverage report,
%   and so that two groups of tests are excluded by tag:
%
%   - "LiveIntegration" tests call the real EBRAINS APIs and run on a
%     schedule instead; see runLiveIntegrationTests and
%     .github/workflows/run-live-tests.yml.
%   - "Graphical" tests open real figure windows and are meant to be run
%     locally. MatBox skips them on GitHub runners on its own, but that
%     check depends on isenv and does not take effect on R2022b, where a
%     headless msgbox returns a placeholder and the tests error.

    projectRootDirectory = ebtools.projectdir();

    matbox.tasks.testToolbox(projectRootDirectory, ...
        varargin{:}, ...
        "ExcludeTags", ["LiveIntegration", "Graphical"], ...
        "CoverageFileList", ebtools.listSourceFiles());
end
