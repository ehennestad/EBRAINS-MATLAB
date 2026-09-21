classdef ViewInstanceOnlineTest < matlab.unittest.TestCase
    % ViewInstanceOnlineTest - Unit tests for ebrains.kg.viewInstanceOnline
    %
    %   The Opener option stands in for WEB, so no browser is opened and the
    %   address the function would have opened can be asserted on.

    properties (Constant)
        Uuid = "08ab00ea-3e19-4300-9d9f-c0ef0ec8e445"
    end

    properties
        OpenedURL (1,:) string
    end

    methods (TestMethodSetup)
        function clearOpenedURL(testCase)
            testCase.OpenedURL = string.empty(1, 0);
        end
    end

    methods (Test)
        function testOpensSearchUrlByDefault(testCase)
            ebrains.kg.viewInstanceOnline(testCase.Uuid, Opener=testCase.makeOpener());

            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(testCase.OpenedURL, expected);
        end

        function testOpensLivePreviewUrl(testCase)
            ebrains.kg.viewInstanceOnline(testCase.Uuid, ...
                View="Live", Opener=testCase.makeOpener());

            expected = ebrains.common.constant.KgInstanceLivePreviewURL() + testCase.Uuid;
            testCase.verifyEqual(testCase.OpenedURL, expected);
        end

        function testOpensEditorUrl(testCase)
            ebrains.kg.viewInstanceOnline(testCase.Uuid, ...
                View="Editor", Opener=testCase.makeOpener());

            expected = ebrains.common.constant.KgInstanceEditorURL() + testCase.Uuid;
            testCase.verifyEqual(testCase.OpenedURL, expected);
        end

        function testUnknownViewIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.viewInstanceOnline(testCase.Uuid, ...
                    View="Atlas", Opener=testCase.makeOpener()), ...
                "MATLAB:validation:UnableToConvert");
        end

        function testOpensUrlForFullIri(testCase)
            fullIri = ebrains.common.constant.KgInstanceIRIPrefix() + "/" + testCase.Uuid;
            ebrains.kg.viewInstanceOnline(fullIri, Opener=testCase.makeOpener());

            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(testCase.OpenedURL, expected);
        end

        function testOpensUrlForOpenMindsInstance(testCase)
            testCase.assumeTrue(exist("openminds.Node", "class") == 8, ...
                "openMINDS_MATLAB is not on the path.");

            % An instance that stands for a node in the Knowledge Graph is
            % built from a struct holding its IRI and nothing else.
            instanceIri = ebrains.common.constant.KgInstanceIRIPrefix() + "/" + testCase.Uuid;
            instance = openminds.core.Person(struct("x_id", instanceIri));

            ebrains.kg.viewInstanceOnline(instance, Opener=testCase.makeOpener());

            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(testCase.OpenedURL, expected);
        end

        function testUnsavedOpenMindsInstanceIsRejected(testCase)
            testCase.assumeTrue(exist("openminds.Node", "class") == 8, ...
                "openMINDS_MATLAB is not on the path.");

            % A newly created instance carries a locally assigned blank node
            % identifier, which the Knowledge Graph has no page for.
            instance = openminds.core.Person();

            testCase.verifyError(...
                @() ebrains.kg.viewInstanceOnline(instance, Opener=testCase.makeOpener()), ...
                "EBRAINS:KG:BlankNodeIdentifier");
        end

        function testStringArrayTargetIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.viewInstanceOnline([testCase.Uuid, testCase.Uuid], ...
                    Opener=testCase.makeOpener()), ...
                "EBRAINS:KG:NonScalarTarget");
        end

        function testUnsupportedTargetClassIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.viewInstanceOnline(42, Opener=testCase.makeOpener()), ...
                "EBRAINS:KG:InvalidTarget");
        end

        function testNothingIsOpenedWhenTargetIsRejected(testCase)
            try
                ebrains.kg.viewInstanceOnline("not-a-uuid", Opener=testCase.makeOpener());
            catch
                % The error itself is asserted on in the tests above.
            end
            testCase.verifyEmpty(testCase.OpenedURL);
        end
    end

    methods (Access = private)
        function opener = makeOpener(testCase)
        % makeOpener - Stand-in for WEB that records the address it is given
            opener = @(url) recordURL(testCase, url);
        end
    end
end

function recordURL(testCase, url)
    testCase.OpenedURL(end+1) = url;
end
