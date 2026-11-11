classdef TestConstants < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function useDefaultPreferences(testCase)
            % The Environment preference selects the URLs of the
            % Collaboratory and the identity provider.
            testCase.applyFixture(ebrains.test.fixtures.PreferencesFixture());
        end
    end

    methods(Test)
        function testCollabBaseUrl(testCase)
            url = ebrains.common.constant.CollabBaseUrl();
            testCase.verifyEqual(url, "https://wiki.ebrains.eu");
        end

        function testCollabApiBaseUrl(testCase)
            url = ebrains.common.constant.CollabApiBaseUrl();
            testCase.verifyEqual(url, "https://wiki.ebrains.eu/rest/v1/");
        end

        function testCollabBaseUrlForIntEnvironment(testCase)
            url = ebrains.common.constant.CollabBaseUrl(Environment="int");
            testCase.verifyEqual(url, "https://wiki-int.ebrains.eu");
        end

        function testCollabApiBaseUrlForIntEnvironment(testCase)
            url = ebrains.common.constant.CollabApiBaseUrl(Environment="int");
            testCase.verifyEqual(url, "https://wiki-int.ebrains.eu/rest/v1/");
        end

        function testIamBaseUrl(testCase)
            url = ebrains.common.constant.IamBaseUrl();
            testCase.verifyEqual(url, "https://iam.ebrains.eu/auth/realms/hbp/");
        end

        function testIamBaseUrlForIntEnvironment(testCase)
            url = ebrains.common.constant.IamBaseUrl(Environment="int");
            testCase.verifyEqual(url, "https://iam-int.ebrains.eu/auth/realms/hbp/");
        end

        function testUrlsFollowTheEnvironmentPreference(testCase)
            ebrains.useEnvironment("int")

            testCase.verifyEqual(ebrains.common.constant.CollabBaseUrl(), "https://wiki-int.ebrains.eu");
            testCase.verifyEqual(ebrains.common.constant.IamBaseUrl(), ...
                "https://iam-int.ebrains.eu/auth/realms/hbp/");
        end

        function testUrlRejectsUnknownEnvironment(testCase)
            testCase.verifyError(@() ebrains.common.constant.CollabBaseUrl(Environment="bogus"), ...
                "EBRAINS:Common:UnknownEnvironment");
        end

        function testDataProxyApiBaseUrl(testCase)
            url = ebrains.common.constant.DataProxyApiBaseUrl();
            testCase.verifyEqual(url, "https://data-proxy.ebrains.eu/api/v1/");
        end

        function testKGCoreApiBaseURL(testCase)
            url = ebrains.common.constant.KGCoreApiBaseURL();
            testCase.verifyEqual(url, "https://core.kg.ebrains.eu/v3");
        end

        function testKgInstanceViewURL(testCase)
            url = ebrains.common.constant.KgInstanceViewURL();
            testCase.verifyEqual(url, "https://search.kg.ebrains.eu/instances/");
        end

        function testKgInstanceLivePreviewURL(testCase)
            url = ebrains.common.constant.KgInstanceLivePreviewURL();
            testCase.verifyEqual(url, "https://search.kg.ebrains.eu/live/");
        end

        function testKgInstanceEditorURL(testCase)
            url = ebrains.common.constant.KgInstanceEditorURL();
            testCase.verifyEqual(url, "https://editor.kg.ebrains.eu/instances/");
        end
    end
end
