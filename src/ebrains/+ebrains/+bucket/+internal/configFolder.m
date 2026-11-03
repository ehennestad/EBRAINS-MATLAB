function folder = configFolder(options)
% configFolder - The configuration folder of the user, where the bucket tools keep their files
%
%   folder = ebrains.bucket.internal.configFolder() returns the folder
%   that spec/README.md#configuration-folder of the ebrains-bucket-sync
%   package gives for the platform, which the package computes the same
%   way, so that the two tools read one registry of virtual buckets:
%
%       macOS    ~/Library/Application Support/ebrains-bucket-sync
%       Windows  %LOCALAPPDATA%\ebrains-bucket-sync, with
%                %USERPROFILE%\AppData\Local where LOCALAPPDATA is not
%                set or empty
%       other    $XDG_CONFIG_HOME/ebrains-bucket-sync, with ~/.config
%                where XDG_CONFIG_HOME is not set or empty
%
%   The environment variable EBRAINS_BUCKET_SYNC_CONFIG_DIR, when set and
%   not empty, names the folder instead. The folder need not exist.
%
%   Name-Value Arguments
%       Platform : "mac", "windows" or "unix". Meant for tests; the
%                  platform of this MATLAB otherwise.
%       Home     : The home folder of the user. Meant for tests; otherwise
%                  HOME, or USERPROFILE on Windows, as the package finds
%                  it, and the user.home property of the Java system where
%                  that is not set.
%
%   See also ebrains.bucket.internal.registry.registryPath

    arguments
        options.Platform (1,1) string {mustBeMember(options.Platform, ["mac", "windows", "unix"])} = thisPlatform()
        options.Home string {mustBeScalarOrEmpty} = string.empty
    end

    appFolder = "ebrains-bucket-sync";

    override = string(getenv("EBRAINS_BUCKET_SYNC_CONFIG_DIR"));
    if override ~= ""
        folder = override;
        return
    end

    home = options.Home;
    if isempty(home)
        home = homeFolder(options.Platform);
    end

    switch options.Platform
        case "mac"
            folder = fullfile(home, "Library", "Application Support", appFolder);
        case "windows"
            base = string(getenv("LOCALAPPDATA"));
            if base == ""
                base = fullfile(home, "AppData", "Local");
            end
            folder = fullfile(base, appFolder);
        otherwise % "unix", the only other platform the argument allows
            base = string(getenv("XDG_CONFIG_HOME"));
            if base == ""
                base = fullfile(home, ".config");
            end
            folder = fullfile(base, appFolder);
    end
end

function home = homeFolder(platform)
% homeFolder - The home folder as Path.home() of Python finds it, so that both tools agree when HOME is overridden
    if platform == "windows"
        home = string(getenv("USERPROFILE"));
    else
        home = string(getenv("HOME"));
    end
    if home == ""
        home = string(java.lang.System.getProperty("user.home"));
    end
end

function platform = thisPlatform()
    if ismac
        platform = "mac";
    elseif ispc
        platform = "windows";
    else
        platform = "unix";
    end
end
