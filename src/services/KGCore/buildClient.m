% Run startup to configure the package's MATLAB paths
startup

% Create a builder object
c = openapi.build.Client;
% Set the package name, defaults to "OpenAPIClient"
c.packageName = "ebrains.kgcore";
% Set the path to the spec., this may also be a HTTP URL
c.inputSpec = "kg_v3.json";
% Set a directory where the results will be stored
c.output = fullfile("/Users/eivihe/Code/MATLAB/Nesys/EBRAINS/services/KGCore");
% Trigger the build process
c.build;


% Todo: 
% Consider programmatically implementing the following edits in the spec
% file:
%   - replace all '*/*' with 'application/json'
%   - rename the client groups

% % str = fileread("kg_v3.json");
% % str = strrep(str, '*/*', 'application/json');
% % str = strrep(str, "1 Basic", "Basic");
% % str = strrep(str, "2 Advanced", "Advanced");
% % str = strrep(str, "3 Admin", "Admin");


