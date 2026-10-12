function text = formatManifest(files)
% formatManifest - Text of a manifest.csv for a file table
%
%   text = ebrains.bucket.internal.metadata.formatManifest(files) returns
%   the header "path,bytes,modified_time,hash" and one line per file,
%   sorted by path, each ending with LF. A field that holds a comma, a
%   double quote or a line break is put in double quotes, with each double
%   quote in it doubled. An unknown time or checksum is an empty field.
%
%   The manifest is shared with the ebrains-bucket-sync package, so the
%   text must be the same byte for byte; see
%   spec/README.md#virtual-buckets of that package.
%
%   See also ebrains.bucket.internal.metadata.parseManifest

    arguments
        files table
    end

    % The spec sorts by Unicode code point, and sortrows sorts text by
    % UTF-16 code unit. The two orders differ only between characters above
    % U+FFFF and those from U+E000 to U+FFFF, which object names do not mix
    % in practice.
    files = sortrows(files, "Path");

    paths = quoteFields(files.Path);
    bytes = compose("%d", files.Bytes);
    times = ebrains.bucket.internal.metadata.formatTimes(files.ModifiedTime);
    hashes = lower(files.Hash);

    lines = paths + "," + bytes + "," + times + "," + hashes + newline;
    text = "path,bytes,modified_time,hash" + newline + join([""; lines], "");
end

function fields = quoteFields(fields)
% quoteFields - Quote the fields that hold a comma, a double quote or a line break
    needsQuotes = contains(fields, [",", """", newline, char(13)]);
    fields(needsQuotes) = """" + replace(fields(needsQuotes), """", """""") + """";
end
