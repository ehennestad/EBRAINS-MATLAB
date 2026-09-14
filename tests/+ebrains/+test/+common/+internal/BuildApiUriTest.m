classdef BuildApiUriTest < matlab.unittest.TestCase
    % BuildApiUriTest - Unit tests for ebrains.common.internal.buildApiUri

    methods (Test)
        function testSegmentsFollowBaseWithoutTrailingSlash(testCase)
            uri = ebrains.common.internal.buildApiUri("https://example.org/v3", ["instances", "abc"]);
            testCase.verifyEqual(char(uri.EncodedURI), 'https://example.org/v3/instances/abc');
        end

        function testTrailingSlashOfBaseIsNotDoubled(testCase)
            uri = ebrains.common.internal.buildApiUri("https://example.org/api/v1/", ["buckets", "b"]);
            testCase.verifyEqual(char(uri.EncodedURI), 'https://example.org/api/v1/buckets/b');
        end

        function testHostOnlyBase(testCase)
            uri = ebrains.common.internal.buildApiUri("https://example.org", ["rest", "v1", "collabs"]);
            testCase.verifyEqual(char(uri.EncodedURI), 'https://example.org/rest/v1/collabs');
        end

        function testSpecialCharactersInsideSegmentAreEncoded(testCase)
            % An object name is one segment even when it holds "/", so the
            % slash is encoded rather than split into two segments.
            uri = ebrains.common.internal.buildApiUri("https://example.org/api/v1/", ...
                ["buckets", "b", "sub dir/file name.txt"]);
            testCase.verifyEqual(char(uri.EncodedURI), ...
                'https://example.org/api/v1/buckets/b/sub%20dir%2Ffile%20name.txt');
        end

        function testRequiredAndOptionalParamsBecomeQuery(testCase)
            uri = ebrains.common.internal.buildApiUri("https://example.org/v3", "instances", ...
                struct('stage', "RELEASED"), struct('size', 5));
            testCase.verifyEqual(char(uri.EncodedURI), ...
                'https://example.org/v3/instances?stage=RELEASED&size=5');
        end

        function testStructsWithoutFieldsGiveNoQuery(testCase)
            uri = ebrains.common.internal.buildApiUri("https://example.org/v3", "instances", ...
                struct.empty, struct());
            testCase.verifyEqual(char(uri.EncodedURI), 'https://example.org/v3/instances');
        end

        function testEnumValueIsSentByName(testCase)
            uri = ebrains.common.internal.buildApiUri("https://example.org/v3", "instances", ...
                struct('stage', ebrains.kg.enum.KGStage.IN_PROGRESS));
            testCase.verifySubstring(char(uri.EncodedURI), 'stage=IN_PROGRESS');
        end
    end
end
