function [newVersion, mltbxPath] = packageToolbox(releaseType, versionString, varargin)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    arguments (Repeating)
        varargin
    end

    projectRootDirectory = ebtools.projectdir();
    [newVersion, mltbxPath] = matbox.tasks.packageToolbox(projectRootDirectory, releaseType, versionString, ...
        varargin{:}, ...
        "ToolboxShortName", "EBRAINS_MATLAB", ...
        "SourceFolderName", "src/ebrains");
end
