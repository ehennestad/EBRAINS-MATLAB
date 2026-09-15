classdef GetDataSizeLabelTest < matlab.unittest.TestCase
    % GetDataSizeLabelTest - Unit tests for ebrains.util.getDataSizeLabel
    %
    % Covers the documented range of the function (a positive byte count
    % well within double precision). 0 and sizes at or above 1e18 bytes
    % are not covered here: both currently error (log10(0) is -Inf, and
    % the largest unit is petabytes), which looks like an unhandled edge
    % case rather than an intended restriction, so this suite does not
    % encode either as expected behavior.

    properties (TestParameter)
        SizeCase = struct(...
            'Bytes',    {{1, '1.00 bytes'}}, ...
            'SubKb',    {{999, '999.00 bytes'}}, ...
            'Kilobyte', {{1e3, '1.00 kB'}}, ...
            'Megabyte', {{1e6, '1.00 MB'}}, ...
            'Gigabyte', {{1e9, '1.00 GB'}}, ...
            'Terabyte', {{1e12, '1.00 TB'}}, ...
            'Petabyte', {{1e15, '1.00 PB'}} ...
            )
    end

    methods (Test)
        function testFormatsSizeWithUnit(testCase, SizeCase)
            sizeInBytes = SizeCase{1};
            expectedLabel = SizeCase{2};

            actual = ebrains.util.getDataSizeLabel(sizeInBytes);

            testCase.verifyEqual(actual, expectedLabel);
        end
    end
end
