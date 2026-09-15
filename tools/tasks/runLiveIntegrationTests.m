function runLiveIntegrationTests()
% runLiveIntegrationTests - Run the tests tagged "LiveIntegration"
%
%   These tests call the real EBRAINS Data Proxy, Knowledge Graph, and
%   Collaboratory APIs with the account of the current session. They are
%   excluded from testToolbox, the task the "Test code" workflow runs on
%   every push and pull request, and run instead on the schedule in
%   .github/workflows/run-live-tests.yml.

    projectRootDirectory = ebtools.projectdir();

    matbox.tasks.testToolbox(projectRootDirectory, ...
        "CreateBadge", false, ...
        "HasTag", "LiveIntegration")
end
