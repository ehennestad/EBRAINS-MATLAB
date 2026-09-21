classdef BuildInstanceViewURLTest < matlab.unittest.TestCase
    % BuildInstanceViewURLTest - Unit tests for ebrains.kg.internal.buildInstanceViewURL

    properties (Constant)
        Uuid = "08ab00ea-3e19-4300-9d9f-c0ef0ec8e445"
        IriPrefix = ebrains.common.constant.KgInstanceIRIPrefix + "/"
    end

    properties (TestParameter)
        % Each view and the constant that holds the URL it is served under
        View = struct( ...
            "Search",  struct("Name", "Search",  "BaseURL", @ebrains.common.constant.KgInstanceViewURL), ...
            "Preview", struct("Name", "Preview", "BaseURL", @ebrains.common.constant.KgInstanceLivePreviewURL), ...
            "Editor",  struct("Name", "Editor",  "BaseURL", @ebrains.common.constant.KgInstanceEditorURL))
    end

    methods (Test)
        function testBuildsUrlForEachView(testCase, View)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, View=View.Name);
            testCase.verifyEqual(actual, View.BaseURL() + testCase.Uuid);
        end

        function testViewNameIsCaseInsensitive(testCase, View)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, View=lower(View.Name));
            testCase.verifyEqual(actual, View.BaseURL() + testCase.Uuid);
        end

        function testAcceptsEnumMember(testCase, View)
            viewEnum = ebrains.kg.enum.InstanceView(View.Name);
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, View=viewEnum);
            testCase.verifyEqual(actual, View.BaseURL() + testCase.Uuid);
        end

        function testDefaultViewIsSearch(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid);
            expected = ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, View="Search");
            testCase.verifyEqual(actual, expected);
        end

        function testEveryViewHasItsOwnUrl(testCase)
            % The views differ only by the constant each maps to, so a
            % copy-paste that made two of them equal must fail here.
            views = enumeration("ebrains.kg.enum.InstanceView");
            urls = arrayfun(...
                @(v) ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, View=v), views);
            testCase.verifyNumElements(unique(urls), numel(views));
        end

        function testBuildsUrlFromFullIri(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(testCase.IriPrefix + testCase.Uuid);
            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(actual, expected);
        end

        function testAcceptsCharIdentifier(testCase)
            actual = ebrains.kg.internal.buildInstanceViewURL(char(testCase.Uuid));
            expected = ebrains.common.constant.KgInstanceViewURL() + testCase.Uuid;
            testCase.verifyEqual(actual, expected);
        end

        function testUnknownViewIsRejected(testCase)
            testCase.verifyError(...
                @() ebrains.kg.internal.buildInstanceViewURL(testCase.Uuid, View="Atlas"), ...
                "MATLAB:validation:UnableToConvert");
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
