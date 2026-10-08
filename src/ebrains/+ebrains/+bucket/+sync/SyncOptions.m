classdef SyncOptions
% SyncOptions - Options of ebrains.bucket.sync.toBucket and ebrains.bucket.sync.fromBucket
%
%   The two sync functions take these options as name-value arguments and
%   hand them on to the sync engine as one object, so the defaults and the
%   validation live here and nowhere else. An object can also be built
%   directly, to see the defaults:
%
%       ebrains.bucket.sync.SyncOptions()
%
%   Properties
%       Prefix      : Folder of the bucket to sync, such as "results/".
%                     Default is "", the root of the bucket. Objects
%                     outside the folder are never changed.
%       Delete      : Delete the files of the target that the source does
%                     not have, which makes the target an exact mirror of
%                     the source. Default is false, which keeps them.
%       Comparison  : How a file on both sides is judged changed:
%                     "SizeAndTime" - (default) the sizes differ, or the
%                                     source was changed after the target
%                     "Size"        - the sizes differ
%                     "Checksum"    - the sizes or the MD5 checksums
%                                     differ. Reads every local file of
%                                     the same size as its object. Where
%                                     the bucket reports no checksum, the
%                                     file is judged as for "SizeAndTime".
%                                     The checksum of an object uploaded
%                                     in segments is not one of its
%                                     content, so such an object is
%                                     transferred on every sync; objects
%                                     above 5 GB are always segmented and
%                                     are judged by time instead.
%       Exclude     : Wildcard patterns of paths to leave out, such as
%                     [".git", "*.tmp", "raw/scratch"]. Excluded files are
%                     neither transferred nor deleted. See
%                     ebrains.bucket.sync.internal.excludeFiles for the rules.
%       DryRun      : Only plan: list what would be transferred and
%                     deleted, and change nothing. A deletion that a real
%                     run would refuse (see MaxDelete) is listed as skipped
%                     with the reason. Default is false.
%       MaxDelete   : Most files the sync may delete. If the plan deletes
%                     more, the sync stops before it changes anything.
%                     Default is Inf.
%       Verbose     : Print the plan and the progress. Default is true.
%       DisplayMode : Where the progress of each transfer is shown:
%                     "Command Window" (default) or "Dialog Box".
%       Uploader    : Function that uploads a file to a signed URL, as for
%                     ebrains.bucket.uploadFile. Meant for tests.
%       Downloader  : Function that downloads a signed URL to a file, as
%                     for ebrains.bucket.downloadFile. Meant for tests.
%
%   See also ebrains.bucket.sync.toBucket, ebrains.bucket.sync.fromBucket

    properties
        Prefix (1,1) string = ""
        Delete (1,1) logical = false
        Comparison (1,1) string ...
            {mustBeMember(Comparison, ["SizeAndTime", "Size", "Checksum"])} = "SizeAndTime"
        Exclude string = string.empty
        DryRun (1,1) logical = false
        MaxDelete (1,1) double {mustBeNonnegative} = Inf
        Verbose (1,1) logical = true
        DisplayMode (1,1) string ...
            {mustBeMember(DisplayMode, ["Dialog Box", "Command Window"])} = "Command Window"
        Uploader (1,1) function_handle = @ebrains.external.webprogress.upload
        Downloader (1,1) function_handle = @ebrains.external.webprogress.download
    end

    methods
        function obj = SyncOptions(options)
        % SyncOptions - Options object from name-value arguments
        %
        %   options = ebrains.bucket.sync.SyncOptions(Name, Value, ...) sets the
        %   named properties and leaves the others at their defaults.

            arguments
                options.?ebrains.bucket.sync.SyncOptions
            end

            for name = string(fieldnames(options))'
                obj.(name) = options.(name);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(options)
        % fromStruct - Options object from a struct of name-value arguments
        %
        %   options = ebrains.bucket.sync.SyncOptions.fromStruct(s) is for a
        %   function that collects the options with options.?SyncOptions
        %   in its arguments block, which gives it a struct.

            arguments
                options (1,1) struct
            end

            nameValues = namedargs2cell(options);
            obj = ebrains.bucket.sync.SyncOptions(nameValues{:});
        end
    end
end
