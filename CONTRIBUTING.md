# Contributing

Thanks for your interest in improving the EBRAINS Services Toolbox.

## Before you start
Open an issue to discuss a bug or an idea before starting on a larger change, so that the approach can be agreed on before the work is done.

## Making a change
1. Fork the repository and create a branch from `main`.
2. Add or update tests for the change where practical. Unit tests live in `tests/+ebrains/+test`, in namespaces that mirror those of `src/ebrains/+ebrains`. They use the test doubles in `tests/+ebrains/+mocks`, so that no request reaches an EBRAINS service.
3. Give new public functions and classes help text in the style of the existing ones.
4. Open a pull request against `main`.

## Running the tests
The toolbox needs MATLAB R2022b or newer. The test tasks in `tools/tasks` build on MatBox, which the CI installs with `ehennestad/matbox-actions/install-matbox` (see `.github/workflows/live-integration-tests.yml`). With MatBox installed, run from the repository root:

```matlab
addpath(genpath("src")), addpath(genpath("tests")), addpath(genpath("tools"))
testToolbox()
```

`testToolbox` leaves out two groups of tests by tag:

- **`LiveIntegration`** tests call the real EBRAINS APIs with the account of the session. Run them with `runLiveIntegrationTests()` after logging in with `ebrains.authenticate`.
- **`Graphical`** tests open figure windows, and are meant to be run locally.

## Checks on a pull request
The "Test code" workflow runs code analysis and the unit tests with coverage. "Run Codespell" checks spelling, with the settings in `tools/.codespellrc`.
