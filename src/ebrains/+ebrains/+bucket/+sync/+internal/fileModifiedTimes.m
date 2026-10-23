function modifiedTimes = fileModifiedTimes(absolutePaths, datenums)
% fileModifiedTimes - Modification time of each file, in UTC
%
%   modifiedTimes = ebrains.bucket.sync.internal.fileModifiedTimes(absolutePaths,
%   datenums) returns the time of the last change of each file as a
%   datetime column in UTC, from the absolute paths of the files and the
%   datenum that dir reports for each.
%
%   dir reports the time as a datenum in local wall-clock time, which is
%   ambiguous for the hour that repeats when daylight saving time ends.
%   The file system holds the time as an instant, which Java reads as
%   milliseconds since the epoch, so that is used where Java is available,
%   and the datenums otherwise. The paths are absolute: Java resolves a
%   relative path against its own working directory, which need not be
%   MATLAB's. A file that vanished since it was listed gets NaT.
%
%   See also ebrains.bucket.sync.internal.listLocalFiles, ebrains.bucket.sync.internal.listLocalFile

    arguments
        absolutePaths string
        datenums double
    end

    if usejava('jvm')
        epochMilliseconds = zeros(numel(absolutePaths), 1);
        for i = 1:numel(absolutePaths)
            epochMilliseconds(i) = java.io.File(char(absolutePaths(i))).lastModified();
        end
        modifiedTimes = datetime(epochMilliseconds / 1000, ...
            'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        % lastModified gives 0 for a file that vanished since the listing
        modifiedTimes(epochMilliseconds == 0) = NaT;
    else
        modifiedTimes = datetime(reshape(datenums, [], 1), 'ConvertFrom', 'datenum', 'TimeZone', 'local');
    end
end
