classdef BuildInstanceViewURLTest < matlab.unittest.TestCase
    % BuildInstanceViewURLTest - Unit tests for ebrains.kg.internal.buildInstanceViewURL

    properties (Constant)
        Uuid = "08ab00ea-3e19-4300-9d9f-c0ef0ec8e445"
        IriPrefix = ebrains.common.constant.KgInstanceIRIPrefix + "/"
    end

    methods (Test)
        function testBuildsViewUrlFromBareUuid(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid);
            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(actual, expected);
        end

        function testBuildsViewUrlFromFullIri(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.IriPrefix + testCase.Uuid);
            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(actual, expected);
        end

        function testBuildsLivePreviewUrl(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, LivePreview=true);
            expected = ebrains.common.constant.KgInstanceLivePreviewURL() + testCase.Uuid;
            testCase.verifyEqual(actual, expected);
        end

        function testLivePreviewAndViewUrlsDiffer(testCase)
            % The two constants are the whole difference between the two
            % pages, so a copy-paste that made them equal must fail here.
            viewUrl = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid);
            liveUrl = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, LivePreview=true);
            testCase.verifyNotEqual(viewUrl, liveUrl);
        end

        function testAcceptsCharIdentifier(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(char(testCase.Uuid));
            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(actual, expected);
        end

        function testBlankNodeIdentifierIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.internal.buildInstanceViewURL("_:" + testCase.Uuid), ...
                "EBRAINS:KG:BlankNodeIdentifier");
        end

        function testNonUuidIdentifierIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.internal.buildInstanceViewURL("not-a-uuid"), ...
                "EBRAINS:KG:InvalidInstanceIdentifier");
        end

        function testEmptyIdentifierIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.internal.buildInstanceViewURL(""), ...
                "EBRAINS:KG:InvalidInstanceIdentifier");
        end

        function testTruncatedUuidIsRejected(testCase)
            % A prefix of a valid UUID must not pass as one.
            testCase.verifyError(...
                @() ebrains.kg.internal.buildInstanceViewURL(extractBefore(testCase.Uuid, 30)), ...
                "EBRAINS:KG:InvalidInstanceIdentifier");
        end
    end
end
