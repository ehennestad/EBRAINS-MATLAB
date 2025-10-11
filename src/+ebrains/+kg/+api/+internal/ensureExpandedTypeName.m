function type = ensureExpandedTypeName(type)
% ensureExpandedTypeName - Expands the type name to its full IRI
%
% Syntax:
%   type = ebrains.kg.api.internal.ensureExpandedTypeName(type) expands the 
%   type name to the full IRI if it is not already in the correct format.
%
% Input Arguments:
%   type - A string representing the type name to be expanded.
%
% Output Arguments:
%   type - The expanded type name in full URI format, if applicable.
%
% Note: If the openMINDS_MATLAB toolbox is installed, this function will use
% the openMINDS type enum to automatically expand a compact type name.

    arguments
        type (1,1) string
    end

    if ~startsWith(type, 'https://openminds.ebrains.eu/') % Todo: get base IRI from constant
        if exist('openminds.enum.Types', 'class') == 8
            typeEnum = openminds.enum.Types(type);
            type = typeEnum.TypeURI;
        else
            error(...
                ['Please provide the type as a an expanded IRI using the ', ...
                'the openMINDS type namespace IRI as a prefix.'])
        end
    end
end
