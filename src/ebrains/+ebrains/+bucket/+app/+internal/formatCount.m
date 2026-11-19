function text = formatCount(count)
% formatCount - Whole number as text with thousands separators
%
%   text = ebrains.bucket.app.internal.formatCount(count) returns the
%   whole number count as text with a comma between each group of three
%   digits, such as "20,481".
    text = regexprep(sprintf("%d", count), "\d(?=(\d{3})+$)", "$0,");
end
