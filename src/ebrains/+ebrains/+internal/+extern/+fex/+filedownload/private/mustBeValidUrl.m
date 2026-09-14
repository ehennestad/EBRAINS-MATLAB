function mustBeValidUrl(urlString)
    try
        matlab.internal.webservices.urlencode(urlString);
    catch ME
        throwAsCaller(ME)
    end
end
