classdef TestConstants < matlab.unittest.TestCase
    methods(Test)
            function testCollabBaseUrl(testCase)
                url = ebrains.common.constant.CollabBaseUrl();
                testCase.verifyEqual(url, "https://wiki.ebrains.eu");
            end

            function testDataProxyApiBaseUrl(testCase)
                url = ebrains.common.constant.DataProxyApiBaseUrl();
                testCase.verifyEqual(url, "https://data-proxy.ebrains.eu/api/v1/");
            end

            function testKGCoreApiBaseURL(testCase)
                url = ebrains.common.constant.KGCoreApiBaseURL();
                testCase.verifyEqual(url, "https://core.kg.ebrains.eu/v3/");
            end
    end
end
