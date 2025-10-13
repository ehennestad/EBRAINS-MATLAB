function typeIRI = ensureExpandedTypeName(type)
% ensureExpandedTypeName - Expands the type name to its full IRI
%
% Syntax:
%   typeIRI = ebrains.kg.api.internal.ensureExpandedTypeName(type) expands the
%   type name to the full IRI if it is not already in the correct format.
%
% Input Arguments:
%   type - A string representing the type name to be expanded.
%
% Output Arguments:
%   typeIRI - The expanded type name in full IRI format, if applicable.
%
% Note: If the openMINDS_MATLAB toolbox is installed, this function will use
% the openMINDS type enum to automatically expand a compact type name.

    arguments
        type (1,1) string
    end

    openMINDSNamespaceIRI = "https://openminds.ebrains.eu"; % Todo: Get from constant

    if ~startsWith(type, openMINDSNamespaceIRI)
        if exist('openminds.enum.Types', 'class') == 8 % openMINDS_MATLAB on path?
            try
                typeEnum = openminds.enum.Types(type);
                typeIRI = typeEnum.TypeURI;
            catch
                error(...
                    ['The type with name "%s" was not identified as a ' ...
                    'registered openMINDS metadata type. Ensure ', ...
                    'openMINDS_MATLAB is up to date or check that you have ', ...
                    'spelled the type name correctly.'], type)
            end
        else
            exampleTypeIRI = sprintf("%s/core/Person", openMINDSNamespaceIRI);
            error(...
                ['Type name must be specified with the openMINDS type ', ...
                 'namespace prefix, e.g "%s"'], exampleTypeIRI) %#ok<SPERR>
        end
    else
        typeIRI = type;
    end
end
