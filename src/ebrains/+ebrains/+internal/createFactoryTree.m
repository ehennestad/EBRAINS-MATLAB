function factoryTree = createFactoryTree()
%createFactoryTree - Build the factory settings tree of the toolbox
%   factoryTree = ebrains.internal.createFactoryTree() returns the
%   matlab.settings.FactoryGroup that holds the default value of every
%   preference of the toolbox. MATLAB calls this function when it loads
%   the factory settings named in resources/settingsInfo.json, and reaches
%   the result as settings().ebrains.
%
%   There is one setting per element of
%   ebrains.internal.getPreferenceDefinitions, whose FactoryValue is the
%   default. A value a user sets becomes the personal value of the
%   setting, which is saved by MATLAB and takes precedence; clearing it
%   returns the preference to the default.
%
%   See also ebrains.internal.getPreferenceDefinitions,
%   ebrains.util.Preferences, ebrains.getpref, ebrains.setpref

    factoryTree = matlab.settings.FactoryGroup.createToolboxGroup("ebrains", Hidden=false);

    for definition = ebrains.internal.getPreferenceDefinitions()
        addSetting(factoryTree, definition.Name, ...
            FactoryValue=definition.FactoryValue, Hidden=false, ...
            ValidationFcn=definition.ValidationFcn);
    end
end
