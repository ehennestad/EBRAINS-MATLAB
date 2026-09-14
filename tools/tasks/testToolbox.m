function testToolbox(varargin)
% testToolbox - Run the test suites with coverage of the toolbox's own source files
%
%   The CI workflow calls this instead of the MatBox task so that vendored
%   code listed in tools/.coverageignore is left out of the coverage report.

    projectRootDirectory = ebtools.projectdir();

    matbox.tasks.testToolbox(projectRootDirectory, ...
        varargin{:}, ...
        "CoverageFileList", ebtools.listSourceFiles());
end
