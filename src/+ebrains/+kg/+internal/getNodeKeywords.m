function varargout = getNodeKeywords(node, keywords)
% getNodeKeywords - Retrieve values of jsonld keywords from a node structure
%
% Syntax:
%   varargout = ebrains.kg.internal.getNodeKeywords(node, keywords) retrieves 
%    values associated with the specified jsonld keywords from the input node 
%    structure.
%   
% Input Arguments:
%   node (1,1) struct: A structure containing node data.
%   keywords (1,1) string: A list of jsonld keywords to retrieve
%   values for.
%
% Output Arguments:
%   varargout: A cell array containing the values retrieved from the
%   node for each specified keyword. If a keyword does not exist in
%   the node, an empty string is returned in its place.
%
% Example:
%   [id, type] = ebrains.kg.internal.getNodeKeywords(metadataNode, "@id", "@type")
%
% Note: As MATLAB does not support fieldnames that start with @, the @-symbol 
%   is replaced with the prefix x_. This function assumes @-keywords are
%   represented with the prefix x_, e.g @type <-> x_type

    arguments
        node (1,1) struct
    end
    arguments (Repeating)
        keywords (1,1) string
    end

    % Matlab will replace the @ used for jsonld keywords with x_,
    % e.g @id -> x_id
    keywords = replace(string(keywords), '@', 'x_');

    numKeywords = numel(keywords);
    varargout = cell(1, numKeywords);
    for i = 1:numKeywords
        if isfield(node, keywords(i))
            varargout{i} = node.(keywords(i));
        else
            varargout{i} = '';
        end
    end
end

