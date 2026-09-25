function factoryTree = createFactoryTree()
%createFactoryTree - Build the factory settings tree of the toolbox
%   factoryTree = ebrains.internal.createFactoryTree() returns the
%   matlab.settings.FactoryGroup that holds the default value of every
%   preference of the toolbox. MATLAB calls this function when it loads
%   the factory settings named in resources/settingsInfo.json, and reaches
%   the result as settings().ebrains.
%
%   The default of a preference is its FactoryValue here. A value a user
%   sets becomes the personal value of the setting, which is saved by
%   MATLAB and takes precedence; clearing it returns the preference to the
%   default given here.
%
%   Add a preference by adding a setting below and a property of the same
%   name to ebrains.util.Preferences, whose help describes what each
%   preference does.
%
%   See also ebrains.util.Preferences, ebrains.getpref, ebrains.setpref

    factoryTree = matlab.settings.FactoryGroup.createToolboxGroup("ebrains", Hidden=false);

    addSetting(factoryTree, "AutoLogin", ...
        FactoryValue=false, Hidden=false, ...
        ValidationFcn=@matlab.settings.mustBeLogicalScalar);

    addSetting(factoryTree, "AutoRenew", ...
        FactoryValue=true, Hidden=false, ...
        ValidationFcn=@matlab.settings.mustBeLogicalScalar);
end
