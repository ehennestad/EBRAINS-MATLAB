classdef TestConstants < matlab.unittest.TestCase
    methods(Test)
        function testCollabBaseUrl(testCase)
            url = ebrains.common.constant.CollabBaseUrl();
            testCase.verifyEqual(url, "https://wiki.ebrains.eu");
        end

        function testCollabApiBaseUrl(testCase)
            url = ebrains.common.constant.CollabApiBaseUrl();
            testCase.verifyEqual(url, "https://wiki.ebrains.eu/rest/v1/");
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
