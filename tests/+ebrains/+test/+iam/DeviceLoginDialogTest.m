classdef DeviceLoginDialogTest < matlab.unittest.TestCase
    % DeviceLoginDialogTest - Smoke test of ebrains.iam.internal.DeviceLoginDialog
    %
    % Opens the real message box and steps it through the stages of a
    % login. Tagged "Graphical": it needs a display, so the CI test task
    % (tools/tasks/testToolbox.m) leaves it out, and it is meant to be run
    % locally.

    methods (Test, TestTags = {'Graphical'})
        function testStagesRunAndTheBoxCloses(testCase)
            dialog = ebrains.iam.internal.DeviceLoginDialog();
            testCase.addTeardown(@() dialog.close());
            figuresBefore = findall(groot, 'Type', 'figure', 'Name', 'Authenticating...');
            testCase.assertNumElements(figuresBefore, 1);

            dialog.showRedirecting()
            dialog.showWaiting()
            dialog.showSuccess()

            figuresAfter = findall(groot, 'Type', 'figure', 'Name', 'Authenticating...');
            testCase.verifyEmpty(figuresAfter);
        end

        function testCloseIsSafeToCallTwice(testCase)
            dialog = ebrains.iam.internal.DeviceLoginDialog();

            dialog.close()
            dialog.close()

            testCase.verifyEmpty(findall(groot, 'Type', 'figure', 'Name', 'Authenticating...'));
        end
    end
end
