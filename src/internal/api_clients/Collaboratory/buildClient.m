% Run startup to configure the package's MATLAB paths
% startup
% cd ..

% Create a builder object
c = openapi.build.Client;
% Set the package name, defaults to "OpenAPIClient"
c.packageName = "ebrains.collaboratory";
% Set the path to the spec., this may also be a HTTP URL
c.inputSpec = "https://wiki.ebrains.eu/bin/download/Collabs/the-collaboratory/Documentation%20Wiki/API/WebHome/openapi.json?rev=1.2";
% Set a directory where the results will be stored
c.output = fullfile("/Users/eivihe/Code/MATLAB/Nesys/EBRAINS/services/Collaboratory");
% Trigger the build process
c.build;