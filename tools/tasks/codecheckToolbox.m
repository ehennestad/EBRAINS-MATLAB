function issues = codecheckToolbox(varargin)
% codecheckToolbox - Run code analysis on the toolbox's own source files
%
%   The CI workflow calls this instead of the MatBox task so that vendored
%   code listed in tools/.coverageignore is left out of the analysis.

    projectRootDirectory = ebtools.projectdir();

    % The explicit file list replaces the source folder the workflow passes.
    issues = matbox.tasks.codecheckToolbox(projectRootDirectory, ...
        varargin{:}, ...
        "FoldersToCheck", string.empty, ...
        "FilesToCheck", ebtools.listSourceFiles());
end
