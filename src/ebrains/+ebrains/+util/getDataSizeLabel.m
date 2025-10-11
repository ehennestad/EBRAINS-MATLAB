function sizeWithUnitAsString = getDataSizeLabel(sizeInBytes)

    sizeUnit = ["bytes", "kB", "MB", "GB", "TB", "PB"];
    
    unitScale = floor( log10(sizeInBytes) / 3 );
    
    sizeAdjusted = sizeInBytes / 10^(3*unitScale);

    sizeWithUnitAsString = sprintf('%.2f %s', sizeAdjusted, sizeUnit(unitScale+1));
end
