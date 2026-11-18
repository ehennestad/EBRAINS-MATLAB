function text = formatCount(count)
% formatCount - Whole number with thousands separators, such as "20,481"
    text = regexprep(sprintf("%d", count), "\d(?=(\d{3})+$)", "$0,");
end
